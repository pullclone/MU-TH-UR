# Sourced only by validate.sh inside its isolated test environment.
# External startup files can reset PATH and escape the private command stubs.
# Bypass only those files for behavior checks; system_startup tests real sourcing
# separately and never invokes network, session, or agent helpers.
source() {
    case $1 in
        /etc/bashrc)
            # Model macOS resetting PS1, including its normal final status of 1.
            if [[ $TEST_CASE == optional_init ]]; then PS1='SYSTEM> '; return 1; fi
            return 0
            ;;
        /usr/share/bash-completion/bash_completion|/etc/bash_completion) return 0 ;;
        *)
            # The test fixture chooses the repository file at runtime.
            # shellcheck disable=SC1090
            builtin source "$@"
            ;;
    esac
}
fail() { printf '%s\n' "$*" >&2; exit 1; }
assert_eq() { [[ $1 == "$2" ]] || fail "expected <$2>, got <$1>: ${3:-}"; }
load() {
    # bashrc is checked independently; its runtime location comes from the harness.
    # shellcheck source=/dev/null
    source "$TEST_REPO/bashrc" > "$HOME/startup-output" 2> "$HOME/startup-errors" || {
        command cat "$HOME/startup-output" "$HOME/startup-errors" >&2
        fail 'bashrc returned failure'
    }
    # Stop before operational tests if any startup change escaped the stubs.
    if [[ $TEST_CASE != system_startup ]]; then
        local tool
        for tool in sudo loginctl curl ssh-add ssh-agent; do
            assert_eq "$(type -P "$tool")" "$TEST_BIN/$tool" "unsafe test PATH for $tool"
        done
    fi
}
expect_failure() { "$@" > "$HOME/result" 2>&1 && fail "unexpected success: $*"; return 0; }
contains() { command grep -F -- "$2" "$1" >/dev/null || fail "missing <$2> in $1"; }
# Invoked through PROMPT_COMMAND to observe the previous command's status.
# Older ShellCheck versions report the same indirect invocation as SC2317.
# shellcheck disable=SC2317,SC2329
capture_status() { printf '%s\n' "$?" >> "$HOME/prompt-status"; }

case $TEST_CASE in
    source_reload)
        # Reproduce a system bashrc that already provides commonly named aliases.
        # The aliases are deliberately used by the separately parsed bashrc.
        # shellcheck disable=SC2262,SC2263
        alias ll='ls -l'
        # shellcheck disable=SC2262,SC2263
        alias search='grep'
        load
        [[ ! -s $HOME/startup-output && ! -s $HOME/startup-errors ]] || fail 'quiet startup produced output'
        for name in mother-status mother-reload mother-disconnect airlock uplink-status uplink-add uplink-reset start-ssh-agent mkcd up ll search gs gd gl net-local net-public scan-proc scan-disk path; do
            declare -F "$name" >/dev/null || fail "missing function: $name"
        done
        command ln -s "$TEST_REPO/bashrc" "$HOME/.bashrc"
        mother-reload > "$HOME/reload-output" 2>&1 || fail 'reload returned failure'
        [[ ! -s $HOME/reload-output ]] || fail 'quiet reload produced output'
        ;;
    system_startup)
        unset -f source
        load
        # Exercise real system startup without calling any operational helpers.
        for name in mother-status airlock start-ssh-agent ll search; do
            declare -F "$name" >/dev/null || fail "system startup did not define $name"
        done
        ;;
    noninteractive)
        old_path=$PATH
        old_hist=$HISTFILE
        # shellcheck source=/dev/null
        source "$TEST_REPO/bashrc" || fail 'noninteractive source returned failure'
        declare -F mother-status >/dev/null && fail 'noninteractive shell was configured'
        assert_eq "$PATH" "$old_path" PATH
        assert_eq "$HISTFILE" "$old_hist" HISTFILE
        ;;
    prompt_scalar|prompt_array)
        if [[ $TEST_CASE == prompt_array ]]; then
            # Expansion belongs to prompt execution after a previous command.
            # shellcheck disable=SC2016
            PROMPT_COMMAND=('capture_status' 'printf "marker\n" >> "$HOME/prompt-marker"')
        else
            # This branch intentionally tests the alternative scalar form.
            # shellcheck disable=SC2178
            PROMPT_COMMAND='capture_status'
        fi
        load
        prompt_script="$(printf '%s;' "${PROMPT_COMMAND[@]}")"
        false
        eval "$prompt_script"
        load
        prompt_script="$(printf '%s;' "${PROMPT_COMMAND[@]}")"
        false
        eval "$prompt_script"
        assert_eq "$(command cat "$HOME/prompt-status")" $'1\n1' 'prompt must preserve previous status and execute once after reload'
        if [[ $TEST_CASE == prompt_array ]]; then
            assert_eq "$(command cat "$HOME/prompt-marker")" $'marker\nmarker' 'all existing prompt array entries retained'
        fi
        ;;
    path_preferences)
        command mkdir -p "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin"
        HISTSIZE=73 HISTFILESIZE=91 HISTCONTROL='' HISTTIMEFORMAT='custom '
        VISUAL='preferred-visual --option' EDITOR='preferred-editor --option'
        load
        first_path=$PATH
        load
        assert_eq "$PATH" "$first_path" 'PATH changed on reload'
        assert_eq "$HISTSIZE" 73 HISTSIZE
        assert_eq "$HISTFILESIZE" 91 HISTFILESIZE
        assert_eq "$HISTCONTROL" '' HISTCONTROL
        assert_eq "$HISTTIMEFORMAT" 'custom ' HISTTIMEFORMAT
        assert_eq "$VISUAL" 'preferred-visual --option' VISUAL
        assert_eq "$EDITOR" 'preferred-editor --option' EDITOR
        assert_eq "$HISTFILE" "$HOME/history" HISTFILE
        ;;
    missing_optional)
        load
        [[ ! -s $HOME/startup-errors ]] || fail 'missing optional programs caused startup errors'
        for name in eza bat starship zoxide micro; do
            command -v "$name" >/dev/null 2>&1 && fail "optional tool leaked into test: $name"
        done
        if [[ -n ${EDITOR:-} ]]; then
            command -v "${EDITOR%% *}" >/dev/null || fail 'default editor does not exist'
        fi
        ll "$HOME" >/dev/null || fail 'plain ls fallback failed'
        [[ ! -s $TEST_CALLS ]] || fail 'startup unexpectedly invoked a session/network tool'
        ;;
    optional_init|optional_init_failure)
        command mkdir "$HOME/optional-bin"
        printf '#!%s\n' "$BASH" > "$HOME/optional-init"
        command cat >> "$HOME/optional-init" <<'INIT'
name="${0##*/}"
printf '%s\n' "$name" >> "$HOME/init-calls"
printf 'printf "%%s\\n" "%s" >> "$HOME/init-evals"\n' "$name"
if [[ $name == starship ]]; then printf 'PS1="STARSHIP> "\n'; fi
exit "${TEST_INIT_STATUS:-0}"
INIT
        command chmod +x "$HOME/optional-init"
        command ln -s "$HOME/optional-init" "$HOME/optional-bin/zoxide"
        command ln -s "$HOME/optional-init" "$HOME/optional-bin/starship"
        PATH="$HOME/optional-bin:$PATH"
        if [[ $TEST_CASE == optional_init_failure ]]; then export TEST_INIT_STATUS=3; fi
        load
        load
        if [[ $TEST_CASE == optional_init_failure ]]; then
            [[ ! -s $HOME/init-evals ]] || fail 'failed integration output was evaluated'
            [[ -n $PS1 ]] || fail 'failed prompt integration left no prompt'
        else
            assert_eq "$(command cat "$HOME/init-calls")" $'zoxide\nstarship' 'optional integrations initialized again on reload'
            assert_eq "$(command cat "$HOME/init-evals")" $'zoxide\nstarship' 'optional integration output not evaluated once'
            assert_eq "$PS1" 'STARSHIP> ' 'system startup reset the prompt on reload'
        fi
        ;;
    navigation)
        load
        builtin cd "$HOME" || fail 'cannot enter test home'
        mkcd 'directory with spaces/child' || fail 'mkcd failed for spaces'
        assert_eq "$PWD" "$HOME/directory with spaces/child" mkcd
        up 2 || fail 'up failed'
        assert_eq "$PWD" "$HOME" up
        expect_failure up 0
        expect_failure up abc
        expect_failure mkcd
        ;;
    search)
        load
        command mkdir "$HOME/corpus"
        printf 'Alpha beta\nalphabet\na.b\n' > "$HOME/corpus/example"
        search -n -i -w alpha "$HOME/corpus" > "$HOME/result" || fail 'search common flags failed without ripgrep'
        contains "$HOME/result" '1:Alpha beta'
        command grep -F alphabet "$HOME/result" >/dev/null && fail 'whole-word search included alphabet'
        search -F -e a.b "$HOME/corpus" > "$HOME/result" || fail 'search fixed expression failed'
        contains "$HOME/result" a.b
        search -l -i alpha "$HOME/corpus" > "$HOME/result" || fail 'search filename listing failed'
        contains "$HOME/result" "$HOME/corpus/example"
        expect_failure search no-such-word "$HOME/corpus"
        ;;
    curl_failure)
        load
        export TEST_CURL_STATUS=28
        net-public > "$HOME/result" 2>&1
        assert_eq "$?" 28 'curl exit code lost'
        contains "$TEST_CALLS" --connect-timeout
        contains "$TEST_CALLS" --max-time
        export TEST_CURL_STATUS=0 TEST_CURL_OUTPUT=203.0.113.1
        result="$(net-public)" || fail 'successful public address lookup failed'
        assert_eq "$result" 203.0.113.1 'public address output'
        ;;
    diagnostics_failure)
        load
        expect_failure net-local
        expect_failure scan-proc
        ;;
    disk)
        load
        command mkdir "$HOME/disk"
        builtin cd "$HOME/disk" || fail 'cannot enter disk fixture'
        scan-disk > "$HOME/result" || fail 'empty directory scan failed'
        printf 'visible\n' > visible
        printf 'hidden\n' > .hidden
        shopt -u dotglob nullglob
        scan-disk > "$HOME/result" || fail 'directory scan failed'
        contains "$HOME/result" ./visible
        contains "$HOME/result" ./.hidden
        shopt -q dotglob && fail 'disk scan changed dotglob'
        shopt -q nullglob && fail 'disk scan changed nullglob'
        ;;
    session_failures)
        load
        export TEST_SUDO_STATUS=3
        expect_failure mother-disconnect
        command grep -F 'Privileges revoked' "$HOME/result" >/dev/null && fail 'revocation failure reported success'
        expect_failure airlock
        export TEST_SUDO_STATUS=0 TEST_LOCK_STATUS=4
        expect_failure airlock
        command grep -F 'Session secured' "$HOME/result" >/dev/null && fail 'failed lock reported a secured session'
        export TEST_LOCK_STATUS=0
        airlock > "$HOME/result" 2>&1 || fail 'successful lock failed'
        ;;
    ssh_failures)
        load
        export TEST_SSH_ADD_STATUS=1
        uplink-status > "$HOME/result" 2>&1 || fail 'empty agent reported unavailable'
        contains "$HOME/result" 'No identities'
        export TEST_SSH_ADD_STATUS=2
        expect_failure uplink-status
        expect_failure uplink-reset
        expect_failure uplink-add
        export TEST_SSH_ADD_STATUS=0 TEST_SUDO_STATUS=3
        expect_failure uplink-reset
        expect_failure start-ssh-agent
        [[ -z ${SSH_AUTH_SOCK:-} ]] || fail 'failed agent start changed socket environment'
        ;;
    real_agent)
        load
        export TEST_REAL_AGENT=1
        start-ssh-agent || fail 'first dedicated agent failed'
        socket=$SSH_AUTH_SOCK
        first_pids="$(command cat "$TEST_AGENT_PIDS")"
        [[ -n $first_pids ]] || fail 'agent PID was not recorded for cleanup'
        command ssh-add -l >/dev/null 2>&1
        assert_eq "$?" 1 'new agent must be reachable and empty'
        start-ssh-agent || fail 'second dedicated agent request failed'
        assert_eq "$SSH_AUTH_SOCK" "$socket" 'agent socket changed'
        assert_eq "$(command cat "$TEST_AGENT_PIDS")" "$first_pids" 'empty live agent was replaced'
        ;;
    installer)
        printf 'original configuration\n' > "$HOME/.bashrc"
        bash "$TEST_REPO/install.sh" >/dev/null || fail 'initial installation failed'
        [[ -L $HOME/.bashrc ]] || fail 'installer did not create a symlink'
        assert_eq "$(command readlink "$HOME/.bashrc")" "$TEST_REPO/bashrc" 'installed link'
        backups=("$HOME"/.bashrc.before-mu-th-ur.*)
        [[ ${#backups[@]} -eq 1 && -f ${backups[0]} ]] || fail 'expected one backup of original file'
        assert_eq "$(command cat "${backups[0]}")" 'original configuration' 'backup contents'
        bash "$TEST_REPO/install.sh" >/dev/null || fail 'second installation failed'
        backups_after=("$HOME"/.bashrc.before-mu-th-ur.*)
        assert_eq "${#backups_after[@]}" "${#backups[@]}" 'repeat installation created another backup'
        command rm "$HOME/.bashrc"
        command ln -s "$HOME/missing-original" "$HOME/.bashrc"
        bash "$TEST_REPO/install.sh" >/dev/null || fail 'dangling symlink installation failed'
        found=0
        for backup in "$HOME"/.bashrc.before-mu-th-ur.*; do
            if [[ -L $backup && $(command readlink "$backup") == "$HOME/missing-original" ]]; then found=1; fi
        done
        assert_eq "$found" 1 'original dangling symlink was not preserved'
        command rm "$HOME/.bashrc"
        command mkdir "$HOME/.bashrc"
        printf 'keep\n' > "$HOME/.bashrc/keep"
        expect_failure bash "$TEST_REPO/install.sh"
        [[ -f $HOME/.bashrc/keep ]] || fail 'directory destination was changed'
        command rm "$HOME/.bashrc/keep"
        command rmdir "$HOME/.bashrc"
        printf 'restore on failed link\n' > "$HOME/.bashrc"
        command mkdir "$HOME/fail-bin"
        printf '#!%s\nexit 6\n' "$BASH" > "$HOME/fail-bin/ln"
        command chmod +x "$HOME/fail-bin/ln"
        expect_failure env PATH="$HOME/fail-bin:$PATH" bash "$TEST_REPO/install.sh"
        [[ -f $HOME/.bashrc && ! -L $HOME/.bashrc ]] || fail 'failed link did not restore original file'
        assert_eq "$(command cat "$HOME/.bashrc")" 'restore on failed link' 'restored content'
        ;;
    *) fail "unknown test case: $TEST_CASE" ;;
esac
exit 0
