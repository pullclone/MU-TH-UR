#!/usr/bin/env bash
# Behavioral checks run in disposable homes with a restricted command path.
set -eu
repo_dir="$(CDPATH='' builtin cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_bash="${BASH}"
# macOS TMPDIR paths can exceed the Unix socket length limit in the agent test.
test_root="$(mktemp -d /tmp/mother-test.XXXXXXXX)"
failures=0
checks=0
cleanup() {
    if [[ -f $test_root/agent-pids ]]; then
        while IFS= read -r pid; do
            case $pid in ''|*[!0-9]*) continue ;; esac
            kill "$pid" 2>/dev/null || :
        done < "$test_root/agent-pids"
    fi
    command rm -rf -- "$test_root"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

command mkdir -p "$test_root/bin"
# Optional integrations stay absent, regardless of the developer's setup.
for name in awk cat chmod cp date dirname du env grep head hostname ln ls mkdir mktemp mv ps readlink rm rmdir sed sort tr uname uptime vi; do
    tool="$(type -P "$name" || :)"
    [[ -z $tool ]] || command ln -s "$tool" "$test_root/bin/$name"
done
command ln -s "$test_bash" "$test_root/bin/bash"
real_ssh_agent="$(type -P ssh-agent || :)"
real_ssh_add="$(type -P ssh-add || :)"

# Tested helpers cannot contact the network, alter sudo, lock a session, or use
# an inherited SSH agent. The real-agent case gets its own socket and PID log.
printf '#!%s\n' "$test_bash" > "$test_root/stub"
cat >> "$test_root/stub" <<'STUB'
name="${0##*/}"
printf '%s' "$name" >> "$TEST_CALLS"
printf ' <%s>' "$@" >> "$TEST_CALLS"
printf '\n' >> "$TEST_CALLS"
case $name in
    sudo) exit "${TEST_SUDO_STATUS:-0}" ;;
    loginctl) exit "${TEST_LOCK_STATUS:-0}" ;;
    curl) printf '%s' "${TEST_CURL_OUTPUT:-}"; exit "${TEST_CURL_STATUS:-0}" ;;
    hostname|ip|ifconfig) exit 4 ;;
    ps) exit 5 ;;
    ssh-add)
        if [[ ${TEST_REAL_AGENT:-0} == 1 ]]; then exec "$TEST_REAL_SSH_ADD" "$@"; fi
        exit "${TEST_SSH_ADD_STATUS:-2}"
        ;;
    ssh-agent)
        if [[ ${TEST_REAL_AGENT:-0} != 1 ]]; then exit 7; fi
        output="$("$TEST_REAL_SSH_AGENT" "$@")"
        status=$?
        if [[ $output =~ SSH_AGENT_PID=([0-9]+) ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}" >> "$TEST_AGENT_PIDS"
        fi
        printf '%s\n' "$output"
        exit "$status"
        ;;
esac
STUB
command chmod +x "$test_root/stub"
for name in sudo loginctl curl hostname ip ifconfig ps ssh-add ssh-agent; do
    command ln -sf "$test_root/stub" "$test_root/bin/$name"
done

record() {
    checks=$((checks + 1))
    if "$@"; then
        printf '[PASS] %s\n' "$check_name"
    else
        printf '[FAIL] %s\n' "$check_name" >&2
        failures=$((failures + 1))
    fi
}
for name in bashrc install.sh tests/validate.sh tests/cases.sh; do
    check_name="$name syntax"
    record "$test_bash" -n "$repo_dir/$name"
done

run_case() {
    local name="$1" mode="${2:--ic}" case_home="$test_root/$1"
    command mkdir -p "$case_home/config" "$case_home/data" "$case_home/state" "$case_home/cache" "$case_home/runtime"
    command chmod 700 "$case_home/runtime"
    # The child shell expands its own isolated TEST_REPO.
    # shellcheck disable=SC2016
    if env -i HOME="$case_home" PATH="$test_root/bin" TERM=dumb LC_ALL=C \
        XDG_CONFIG_HOME="$case_home/config" XDG_DATA_HOME="$case_home/data" \
        XDG_STATE_HOME="$case_home/state" XDG_CACHE_HOME="$case_home/cache" \
        XDG_RUNTIME_DIR="$case_home/runtime" HISTFILE="$case_home/history" \
        MOTHER_BANNER=0 TEST_REPO="$repo_dir" TEST_CASE="$name" TEST_BIN="$test_root/bin" \
        TEST_CALLS="$case_home/calls" TEST_AGENT_PIDS="$test_root/agent-pids" \
        TEST_REAL_SSH_AGENT="$real_ssh_agent" TEST_REAL_SSH_ADD="$real_ssh_add" \
        "$test_bash" --noprofile --norc "$mode" 'source "$TEST_REPO/tests/cases.sh"' \
        > "$case_home/output" 2>&1; then
        return 0
    fi
    command cat "$case_home/output" >&2
    return 1
}
for name in source_reload system_startup noninteractive prompt_scalar path_preferences missing_optional optional_init optional_init_failure navigation search curl_failure diagnostics_failure disk session_failures ssh_failures ssh_paths installer; do
    check_name="$name"
    if [[ $name == noninteractive ]]; then record run_case "$name" -c; else record run_case "$name"; fi
done
if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )); then
    check_name='prompt_array'
    record run_case prompt_array
else
    printf '[SKIP] prompt arrays require Bash 4.4 or newer\n'
fi
if [[ -n $real_ssh_agent && -n $real_ssh_add ]]; then
    check_name='empty SSH agent reuse'
    record run_case real_agent
else
    printf '[SKIP] real-agent reuse: OpenSSH tools unavailable\n'
fi
if (( failures )); then
    printf '%d of %d checks failed\n' "$failures" "$checks" >&2
    exit 1
fi
printf 'All %d behavioral checks passed.\n' "$checks"
