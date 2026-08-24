# ~/.bashrc — MU/TH/UR operator shell
# A small, predictable interactive Bash baseline.

[[ $- != *i* ]] && return

[[ -r /etc/bashrc ]] && source /etc/bashrc
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
    source /etc/bash_completion
fi

shopt -s checkwinsize histappend 2>/dev/null
bind 'set bell-style none' 2>/dev/null
bind 'set completion-ignore-case on' 2>/dev/null
bind 'set show-all-if-ambiguous on' 2>/dev/null

export HISTSIZE=1000000
export HISTFILESIZE=2000000
export HISTTIMEFORMAT='%F %T '
export HISTCONTROL='erasedups:ignoredups:ignorespace'
__mother_history_sync() { builtin history -a; }
case ";${PROMPT_COMMAND:-};" in
    *';__mother_history_sync;'*) ;;
    ';;') PROMPT_COMMAND='__mother_history_sync' ;;
    *) PROMPT_COMMAND="__mother_history_sync;${PROMPT_COMMAND}" ;;
esac

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export VISUAL="${VISUAL:-micro}"
export EDITOR="${EDITOR:-$VISUAL}"
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
__mother_path_append() { [[ -d $1 && :$PATH: != *":$1:"* ]] && PATH="$PATH:$1"; }
__mother_path_prepend "$HOME/.local/bin"
__mother_path_prepend "$HOME/.cargo/bin"
__mother_path_prepend "$GOBIN"
export PATH

MOTHER_BLUE=$'\e[38;5;33m'
MOTHER_DIM=$'\e[2m'
MOTHER_BOLD=$'\e[1m'
MOTHER_RESET=$'\e[0m'
__mother_has() { command -v "$1" >/dev/null 2>&1; }
__mother_log() { printf '%b[%s]%b %s\n' "$MOTHER_BLUE" "$1" "$MOTHER_RESET" "$2"; }
__mother_banner() {
    printf '%b' "$MOTHER_BLUE$MOTHER_BOLD"
    if __mother_has figlet; then command figlet -f small 'MU/TH/UR'; else printf '[MU/TH/UR]\n'; fi
    printf '%b:: %s ::%b\n' "$MOTHER_DIM" "$1" "$MOTHER_RESET"
}

mother-status() {
    __mother_banner 'SYSTEM STATUS'
    __mother_log HOST "$(command hostname)"
    __mother_log UPTIME "$(command uptime -p 2>/dev/null || printf 'unavailable')"
    __mother_log LOAD "$(command awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || printf 'unavailable')"
    __mother_log MODE "$MOTHER_MODE"
}
mother-reload() { source "$HOME/.bashrc"; }
mother-disconnect() {
    command sudo -k
    __mother_banner 'UPLINK TERMINATED'
    __mother_log AUTH 'Privileges revoked'
}

airlock() {
    command sudo -k
    __mother_has loginctl && command loginctl lock-session 2>/dev/null
    __mother_log AIRLOCK 'Session secured'
}
uplink-status() { command ssh-add -l 2>/dev/null || __mother_log UPLINK 'No identities'; }
uplink-add() { command ssh-add "$@"; }
uplink-reset() { command ssh-add -D 2>/dev/null; command sudo -k; }

start-ssh-agent() {
    local socket_dir="${XDG_RUNTIME_DIR:-$HOME/.ssh/sockets}" socket
    socket="$socket_dir/mother-ssh-agent.socket"
    command mkdir -p "$socket_dir" || return
    command chmod 700 "$socket_dir" 2>/dev/null
    if [[ -S $socket ]] && SSH_AUTH_SOCK="$socket" command ssh-add -l >/dev/null 2>&1; then
        export SSH_AUTH_SOCK="$socket"
        return
    fi
    command rm -f "$socket"
    eval "$(command ssh-agent -s -a "$socket")" >/dev/null
}

mkcd() {
    [[ $# -eq 1 ]] || { printf 'usage: mkcd DIRECTORY\n' >&2; return 2; }
    command mkdir -p -- "$1" && builtin cd -- "$1"
}
up() {
    local count="${1:-1}" path='' i
    [[ $count =~ ^[1-9][0-9]*$ ]] || { printf 'usage: up [POSITIVE_COUNT]\n' >&2; return 2; }
    for ((i = 0; i < count; i++)); do path+='../'; done
    builtin cd -- "$path"
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
    if __mother_has rg; then command rg "$@"; else command grep -R -- "$@"; fi
}

gs() { command git status "$@"; }
gd() { command git diff "$@"; }
gl() { command git log --oneline --decorate "$@"; }
net-local() { command hostname -I 2>/dev/null | command awk '{print $1}'; }
net-public() {
    __mother_has curl || { printf 'curl is required\n' >&2; return 127; }
    command curl --fail --silent --show-error --location https://ifconfig.me
    printf '\n'
}
scan-proc() { __mother_banner 'PROCESS SCAN'; command ps aux --sort=-%mem | command head -n 15; }
scan-disk() { __mother_banner 'DISK'; command du -sh -- ./* 2>/dev/null | command sort -h; }
path() { printf '%s\n' "${PATH//:/$'\n'}"; }

__mother_has eza && alias ls='eza -a --icons --group-directories-first'
__mother_has bat && alias cat='bat'
if __mother_has zoxide; then
    eval "$(command zoxide init bash)"
    bind '"\C-f":"zi\n"' 2>/dev/null
fi
if __mother_has starship; then
    eval "$(command starship init bash)"
else
    PS1='[\u@\h \W] $ '
fi

[[ ${MOTHER_BANNER:-0} == 1 ]] && mother-status
