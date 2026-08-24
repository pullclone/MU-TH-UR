#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bashrc="$repo_dir/bashrc"
failures=0
pass() { printf '[PASS] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1" >&2; failures=$((failures + 1)); }

bash -n "$bashrc" && pass 'bashrc syntax' || fail 'bashrc syntax'
bash -n "$repo_dir/install.sh" && pass 'installer syntax' || fail 'installer syntax'
if grep -Eiq '(^|[^[:alnum:]_])(aiswap|aichat|mother-ai|MOTHER_AI)([^[:alnum:]_]|$)' "$bashrc" "$repo_dir/install.sh"; then
    fail 'AI integration is absent'
else
    pass 'AI integration is absent'
fi
duplicates="$(sed -nE "s/^[[:space:]]*alias[[:space:]]+([^=]+)=.*/\\1/p" "$bashrc" | sort | uniq -d)"
if [[ -n $duplicates ]]; then fail "aliases are unique: $duplicates"; else pass 'aliases are unique'; fi

temp_home="$(mktemp -d)"
trap 'rm -rf -- "$temp_home"' EXIT
HOME="$temp_home" MOTHER_BANNER=0 bash --noprofile --norc -ic '
    source '"$(printf '%q' "$bashrc")"'
    for name in mother-status mother-reload mother-disconnect airlock uplink-status uplink-add uplink-reset start-ssh-agent mkcd up ll search gs gd gl net-local net-public scan-proc scan-disk path; do
        declare -F "$name" >/dev/null || exit 1
    done
' >/dev/null 2>&1 && pass 'public commands load' || fail 'public commands load'

if ((failures)); then printf '%d validation check(s) failed\n' "$failures" >&2; exit 1; fi
printf 'MU/TH/UR baseline is clean.\n'
