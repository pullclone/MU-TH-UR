# ~/.bashrc — MU/TH/UR operator shell
# A small, predictable interactive Bash baseline.

[[ $- != *i* ]] && return 0

# Reloading system settings can reset a prompt that was already initialized.
if [[ -z ${__mother_system_loaded:-} ]]; then
    __mother_system_loaded=1
    if [[ -r /etc/bashrc ]]; then
        # shellcheck disable=SC1091
        source /etc/bashrc
    fi
fi
# Current bash-completion requires Bash 4.2; older shells keep builtin completion.
if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2) )) &&
    [[ -z ${BASH_COMPLETION_VERSINFO:-} ]]; then
    if [[ -r /usr/share/bash-completion/bash_completion ]]; then
        # shellcheck disable=SC1091
        source /usr/share/bash-completion/bash_completion
    elif [[ -r /etc/bash_completion ]]; then
        # shellcheck disable=SC1091
        source /etc/bash_completion
    fi
fi

# System aliases (notably ll) otherwise expand inside function declarations.
unalias mother-status mother-reload mother-disconnect airlock uplink-status \
    uplink-add uplink-reset start-ssh-agent mkcd up ll search gs gd gl \
    net-local net-public scan-proc scan-disk path 2>/dev/null || :

shopt -s checkwinsize histappend 2>/dev/null
bind 'set bell-style none' 2>/dev/null
bind 'set completion-ignore-case on' 2>/dev/null
bind 'set show-all-if-ambiguous on' 2>/dev/null

export HISTSIZE="${HISTSIZE-1000000}"
export HISTFILESIZE="${HISTFILESIZE-2000000}"
export HISTTIMEFORMAT="${HISTTIMEFORMAT-%F %T }"
export HISTCONTROL="${HISTCONTROL-erasedups:ignorespace}"
__mother_history_sync() { local status=$?; builtin history -a; return "$status"; }
case ";${PROMPT_COMMAND:-};" in
    *';__mother_history_sync;'*) ;;
    ';;') PROMPT_COMMAND='__mother_history_sync' ;;
    *) PROMPT_COMMAND="__mother_history_sync;${PROMPT_COMMAND}" ;;
esac

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
if [[ -z ${VISUAL:-} && -n ${EDITOR:-} ]]; then
    export VISUAL="$EDITOR"
elif [[ -z ${VISUAL:-} ]]; then
    for __mother_editor in micro nano vi; do
        if type -P "$__mother_editor" >/dev/null; then
            export VISUAL="$__mother_editor"
            break
        fi
    done
    unset __mother_editor
fi
[[ -n ${VISUAL:-} ]] && export EDITOR="${EDITOR:-$VISUAL}"
export CLICOLOR=1
export GOPATH="${GOPATH:-$HOME/go}"
export GOBIN="${GOBIN:-$GOPATH/bin}"
export MOTHER_MODE="${MOTHER_MODE:-SAFE}"

export LESS_TERMCAP_mb=$'\e[1;31m'
export LESS_TERMCAP_md=$'\e[1;31m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;44;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;32m'

__mother_path_prepend() { [[ -d $1 && :$PATH: != *":$1:"* ]] && PATH="$1:$PATH"; }
__mother_path_prepend "$HOME/.local/bin"
__mother_path_prepend "$HOME/.cargo/bin"
__mother_path_prepend "$GOBIN"
export PATH

MOTHER_BLUE=$'\e[38;5;33m'
MOTHER_DIM=$'\e[2m'
MOTHER_BOLD=$'\e[1m'
MOTHER_RESET=$'\e[0m'
__mother_has() { type -P "$1" >/dev/null 2>&1; }
__mother_log() { printf '%b[%s]%b %s\n' "$MOTHER_BLUE" "$1" "$MOTHER_RESET" "$2"; }
__mother_banner() {
    printf '%b' "$MOTHER_BLUE$MOTHER_BOLD"
    if __mother_has figlet; then command figlet -f small 'MU/TH/UR'; else printf '[MU/TH/UR]\n'; fi
    printf '%b:: %s ::%b\n' "$MOTHER_DIM" "$1" "$MOTHER_RESET"
}

mother-status() {
    __mother_banner 'SYSTEM STATUS'
    __mother_log HOST "$(command hostname)"
    __mother_log UPTIME "$(command uptime -p 2>/dev/null || command uptime 2>/dev/null || printf 'unavailable')"
    __mother_log LOAD "$(command awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || printf 'unavailable')"
    __mother_log MODE "$MOTHER_MODE"
}
mother-reload() {
    # shellcheck disable=SC1091
    source "$HOME/.bashrc"
}
__mother_revoke_sudo() {
    __mother_has sudo || { printf 'sudo is unavailable; privileges were not revoked\n' >&2; return 127; }
    local status=0
    command sudo -k || status=$?
    if ((status)); then
        printf 'Could not revoke sudo credentials\n' >&2
        return "$status"
    fi
    __mother_log AUTH 'Sudo credentials revoked'
}
mother-disconnect() {
    __mother_revoke_sudo || return
    __mother_banner 'UPLINK TERMINATED'
}

airlock() {
    local status=0
    __mother_revoke_sudo || status=$?
    if ! __mother_has loginctl; then
        printf 'Session locking is unavailable (loginctl is required)\n' >&2
        return 127
    fi
    if command loginctl lock-session; then
        __mother_log AIRLOCK 'Lock requested'
    else
        status=$?
        printf 'Session lock request failed\n' >&2
    fi
    return "$status"
}
uplink-status() {
    __mother_has ssh-add || { printf 'ssh-add is required\n' >&2; return 127; }
    local status=0
    command ssh-add -l || status=$?
    case $status in
        0) return 0 ;;
        1) __mother_log UPLINK 'No identities' ;;
        *) printf 'Unable to query SSH agent\n' >&2; return "$status" ;;
    esac
}
uplink-add() { command ssh-add "$@"; }
uplink-reset() {
    local status=0
    command ssh-add -D || status=$?
    __mother_revoke_sudo || return
    return "$status"
}

start-ssh-agent() {
    if ! __mother_has ssh-agent || ! __mother_has ssh-add; then
        printf 'ssh-agent and ssh-add are required\n' >&2
        return 127
    fi
    local socket_dir="${XDG_RUNTIME_DIR:-$HOME/.ssh/sockets}" socket agent_env
    socket="$socket_dir/mother-ssh-agent.socket"
    command mkdir -p -- "$socket_dir" || return
    [[ -O $socket_dir && ! -L $socket_dir ]] || { printf 'SSH socket directory must be owned by you and not a symlink\n' >&2; return 1; }
    command chmod 700 "$socket_dir" || return
    # Serialize the probe and stale-socket removal across concurrent shells.
    agent_env=$(
        command mkdir -- "$socket.lock" 2>/dev/null || { printf 'Cannot acquire SSH startup lock at %s (busy or not writable)\n' "$socket.lock" >&2; exit 1; }
        trap 'command rmdir -- "$socket.lock"' EXIT
        if [[ -L $socket || ( -e $socket && ! -S $socket ) ]]; then
            printf 'Refusing to replace a non-socket SSH path\n' >&2
            exit 1
        fi
        if [[ -S $socket ]]; then
            status=0
            SSH_AUTH_SOCK="$socket" command ssh-add -l >/dev/null 2>&1 || status=$?
            # Avoid case-pattern parentheses inside $() for Bash 3.2's parser.
            if (( status == 0 || status == 1 )); then
                [[ ${SSH_AUTH_SOCK:-} == "$socket" ]] || printf 'unset SSH_AGENT_PID;\n'
                printf 'export SSH_AUTH_SOCK=%q;\n' "$socket"
                exit 0
            elif (( status == 2 )); then
                command rm -f -- "$socket" || exit
            else
                printf 'SSH agent probe failed\n' >&2
                exit "$status"
            fi
        fi
        command ssh-agent -s -a "$socket"
    ) || return
    eval "$agent_env" >/dev/null
}

mkcd() {
    [[ $# -eq 1 ]] || { printf 'usage: mkcd DIRECTORY\n' >&2; return 2; }
    # Enter the path just created, even when the caller uses CDPATH.
    local CDPATH=''
    command mkdir -p -- "$1" || return
    builtin cd -- "$1" || return
}
up() {
    local count="${1-1}" path='' i
    [[ $# -le 1 && $count =~ ^[1-9][0-9]*$ ]] || { printf 'usage: up [POSITIVE_COUNT]\n' >&2; return 2; }
    for ((i = 0; i < count; i++)); do path+='../'; done
    builtin cd -- "$path" || return
}
alias ..='cd ..'
alias ...='cd ../..'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

ll() {
    if __mother_has eza; then command eza -al --icons --group-directories-first "$@"; else command ls -alF "$@"; fi
}
search() {
    # Preserve ripgrep's full interface when installed.
    if __mother_has rg; then command rg "$@"; return; fi
    # The fallback accepts a documented shared subset of options.
    local options=() has_pattern=0 fixed=0
    while (($#)); do
        case $1 in
            -n|-i|-l|-w) options+=("$1"); shift ;;
            -F) options+=("$1"); fixed=1; shift ;;
            -e)
                [[ $# -ge 2 ]] || { printf 'search: -e requires a pattern\n' >&2; return 2; }
                options+=(-e "$2"); has_pattern=1; shift 2
                ;;
            --) shift; break ;;
            -*) printf 'usage: search [-n] [-i] [-l] [-w] [-F] [-e PATTERN] [--] [PATTERN] [PATH...]\n' >&2; return 2 ;;
            *) break ;;
        esac
    done
    if (( ! has_pattern )); then
        [[ $# -ge 1 ]] || { printf 'search: a pattern is required\n' >&2; return 2; }
        options+=(-e "$1"); shift
    fi
    (($#)) || set -- .
    if ((fixed)); then
        command grep -r "${options[@]}" -- "$@"
    else
        command grep -r -E "${options[@]}" -- "$@"
    fi
}

gs() { command git status "$@"; }
gd() { command git diff "$@"; }
gl() { command git log --oneline --decorate "$@"; }
net-local() {
    local addresses
    if ! addresses=$(command hostname -I 2>/dev/null) || [[ -z ${addresses//[[:space:]]/} ]]; then
        printf 'Local address lookup is unavailable on this system (hostname -I)\n' >&2
        return 1
    fi
    command awk '{print $1; exit}' <<< "$addresses"
}
net-public() {
    __mother_has curl || { printf 'curl is required\n' >&2; return 127; }
    command curl --fail --silent --show-error --location --connect-timeout 5 --max-time 15 https://ifconfig.me || return
    printf '\n'
}
scan-proc() {
    local processes
    processes=$(command ps aux --sort=-%mem 2>/dev/null) || { printf 'Process sorting is unavailable on this system (GNU ps is required)\n' >&2; return 1; }
    __mother_banner 'PROCESS SCAN'
    command head -n 15 <<< "$processes"
}
scan-disk() (
    # Include hidden entries without changing the caller's glob settings.
    shopt -s dotglob nullglob
    local entries=(./*) sizes
    __mother_banner 'DISK'
    ((${#entries[@]})) || return 0
    sizes=$(command du -sh -- "${entries[@]}") || return
    command sort -h <<< "$sizes"
)
path() { printf '%s\n' "${PATH//:/$'\n'}"; }

__mother_has eza && alias ls='eza -a --icons --group-directories-first'
__mother_has bat && alias cat='bat'
if [[ -z ${__mother_zoxide_loaded:-} ]] && __mother_has zoxide; then
    if __mother_init=$(command zoxide init bash) && eval "$__mother_init"; then
        __mother_zoxide_loaded=1
        bind '"\C-f":"zi\n"' 2>/dev/null
    else
        printf 'Could not initialize zoxide\n' >&2
    fi
fi
if [[ -z ${__mother_starship_loaded:-} ]]; then
    PS1='[\u@\h \W] $ '
    if __mother_has starship; then
        if __mother_init=$(command starship init bash) && eval "$__mother_init"; then
            __mother_starship_loaded=1
        else
            printf 'Could not initialize starship\n' >&2
        fi
    fi
fi
unset __mother_init

if [[ ${MOTHER_BANNER:-0} == 1 ]]; then mother-status; fi
return 0
