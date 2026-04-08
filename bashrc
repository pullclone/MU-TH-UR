# ~/.bashrc — MU/TH/UR Structured Operator Shell
# Maintainer: Ethan P. Kelley
# Rebuilt: 2026-04-07

#######################################################
# INTERACTIVE GUARD
#######################################################
[[ $- != *i* ]] && return

#######################################################
# SYSTEM CONFIG
#######################################################
[[ -f /etc/bashrc ]] && source /etc/bashrc

#######################################################
# COMPLETION
#######################################################
[[ -f /usr/share/bash-completion/bash_completion ]] && source /usr/share/bash-completion/bash_completion
[[ -f /etc/bash_completion ]] && source /etc/bash_completion

#######################################################
# SHELL OPTIONS
#######################################################
shopt -s checkwinsize histappend 2>/dev/null
bind "set bell-style none" 2>/dev/null
bind "set completion-ignore-case on" 2>/dev/null
bind "set show-all-if-ambiguous on" 2>/dev/null

#######################################################
# HISTORY
#######################################################
export HISTSIZE=1000000
export HISTFILESIZE=2000000
export HISTTIMEFORMAT="%F %T "
export HISTCONTROL="erasedups:ignoredups:ignorespace"

__hist_sync(){ history -a; }
case ";$PROMPT_COMMAND;" in
*";__hist_sync;"*) ;;
"") PROMPT_COMMAND="__hist_sync" ;;
*)  PROMPT_COMMAND="__hist_sync;$PROMPT_COMMAND" ;;
esac

#######################################################
# ENVIRONMENT
#######################################################
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export VISUAL="${VISUAL:-micro}"
export EDITOR="${EDITOR:-$VISUAL}"
export CLICOLOR=1

export GOPATH="${GOPATH:-$HOME/go}"
export GOBIN="${GOBIN:-$GOPATH/bin}"

#######################################################
# PATH
#######################################################
__path_prepend(){ [[ -d "$1" && ":$PATH:" != *":$1:"* ]] && PATH="$1:$PATH"; }
__path_prepend "$HOME/.local/bin"
__path_prepend "$HOME/.cargo/bin"
__path_prepend "$GOBIN"
export PATH

#######################################################
# START DIRECTORY
#######################################################
[[ -d "$HOME/Dev" ]] && cd "$HOME/Dev"

#######################################################
# MU/TH/UR CORE
#######################################################
M_BLUE='\e[38;5;33m'
M_DIM='\e[2m'
M_BOLD='\e[1m'
M_RESET='\e[0m'

_cmd(){ command -v "$1" >/dev/null 2>&1; }

_mlog(){ printf "%b[%s]%b %s\n" "$M_BLUE" "$1" "$M_RESET" "$2"; }

_mbanner(){
    echo -e "${M_BLUE}${M_BOLD}"
    _cmd figlet && figlet -f small "MU/TH/UR" || echo "[MU/TH/UR]"
    echo -e "${M_DIM}:: $1 ::${M_RESET}"
}

export MOTHER_MODE="${MOTHER_MODE:-SAFE}"

#######################################################
# SYSTEM DOMAIN
#######################################################
mother-status(){
    _mbanner "SYSTEM STATUS"
    _mlog HOST "$(hostname)"
    _mlog UPTIME "$(uptime -p 2>/dev/null)"
    _mlog LOAD "$(cut -d ' ' -f1-3 /proc/loadavg 2>/dev/null)"
    _mlog MODE "$MOTHER_MODE"
    _mlog AI "${MOTHER_AI_PROFILE:-unset}"
}

mother-reload(){ source "$HOME/.bashrc"; }

mother-disconnect(){
    sudo -k
    _mbanner "UPLINK TERMINATED"
    _mlog AUTH "Privileges revoked"
}

#######################################################
# SECURITY DOMAIN
#######################################################
airlock(){
    sudo -k
    _cmd loginctl && loginctl lock-session 2>/dev/null
    _mlog AIRLOCK "Session secured"
}

uplink-status(){ ssh-add -l 2>/dev/null || _mlog UPLINK "No identities"; }
uplink-reset(){ ssh-add -D 2>/dev/null; sudo -k; }

#######################################################
# NAVIGATION
#######################################################
cargo-mkcd(){ mkdir -p "$1" && cd "$1"; }

cargo-up(){
    local n="${1:-1}" p=""
    for ((i=0;i<n;i++)); do p="../$p"; done
    cd "$p"
}

#######################################################
# FILE OPS
#######################################################
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -pv'

cargo-list(){ _cmd eza && eza -al --icons || ls -alF; }
cargo-search(){ _cmd rg && rg "$@" || grep -R "$@"; }

#######################################################
# DEV DOMAIN
#######################################################
hyper-status(){ git status; }
hyper-add(){ git add "$@"; }
hyper-commit(){ git commit "$@"; }
hyper-push(){ git push; }
hyper-log(){ git log --oneline; }
hyper-diff(){ git diff; }

#######################################################
# NETWORK
#######################################################
net-local(){ hostname -I | awk '{print $1}'; }
net-public(){ curl -s https://ifconfig.me; }

#######################################################
# OBSERVABILITY
#######################################################
scan-proc(){
    _mbanner "PROCESS SCAN"
    ps aux --sort=-%mem | head -n 15
}

scan-disk(){
    _mbanner "DISK"
    du -sh * 2>/dev/null | sort -h
}

#######################################################
# SSH AGENT
#######################################################
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

start_ssh_agent(){ ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null; }

if ! ssh-add -l >/dev/null 2>&1; then
    pgrep -u "$USER" ssh-agent >/dev/null || start_ssh_agent
    [[ -f "$HOME/.ssh/id_ed25519" ]] && ssh-add "$HOME/.ssh/id_ed25519" >/dev/null 2>&1
fi

mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh/sockets" 2>/dev/null

#######################################################
# AICHAT CORE (v1.2.0 — integrated)
#######################################################
_aichat_swap() {
    local VERSION="1.2.0"
    local BASE_DIR="${AICHAT_CONF_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/aichat}"
    local DIR="$BASE_DIR"
    local BACKUP_DIR="$DIR/backups"
    local LOCK_DIR="$DIR/.swap.lock.d"
    local CURRENT_FILE="$DIR/current"
    local ALIAS_FILE="$DIR/aliases"

    local IDS=(c g m o)
    local NAMES=(altostrat alpha lechat stargate)

    local DRY_RUN=false VERBOSE=false TMPFILE="" HAVE_LOCK=false

    _msg(){ printf "%s\n" "$*"; }
    _exec(){ "$@"; }

    _get_name(){
        local target="$1" i
        for i in "${!IDS[@]}"; do
            [[ "${IDS[$i]}" == "$target" ]] && echo "${NAMES[$i]}" && return
        done
        echo "unknown"
    }

    _alias_list(){ [[ -f "$ALIAS_FILE" ]] && cat "$ALIAS_FILE"; }

    _alias_write(){
        local tmp; tmp=$(mktemp "$DIR/.aliases.tmp.XXXXXX") || return 1
        cat > "$tmp"; mv "$tmp" "$ALIAS_FILE"
    }

    _rebuild_aliases(){
        [[ -f "$ALIAS_FILE" ]] || return
        while read -r id name; do
            [[ -z "$id" || -z "$name" ]] && continue
            alias "$name"="_aichat_swap $id"
        done < "$ALIAS_FILE"
        alias aiswap="_aichat_swap"
    }

    local cmd="${1:-status}"

    if [[ "$cmd" == "alias" ]]; then
        case "$2" in
            list) _alias_list ;;
            rebuild) _rebuild_aliases ;;
        esac
        return
    fi

    if [[ "$cmd" == "status" ]]; then
        [[ -f "$CURRENT_FILE" ]] && cat "$CURRENT_FILE"
        return
    fi

    # simple swap
    local target="$cmd"
    local src="$DIR/$target.config.yaml"

    [[ ! -f "$src" ]] && { echo "Missing profile: $target"; return 1; }

    cp "$src" "$DIR/config.yaml"
    printf "%s" "$target" > "$CURRENT_FILE"

    echo "Switched → $(_get_name "$target") [$target]"
}

#######################################################
# AICHAT INIT + ENV BINDING
#######################################################
if [[ $- == *i* ]]; then
    _aichat_swap alias rebuild 2>/dev/null

    if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/aichat/current" ]]; then
        export MOTHER_AI_PROFILE="$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/aichat/current")"
    fi
fi

#######################################################
# MU/TH/UR AI INTERFACE
#######################################################
mother-ai(){
    _mbanner "AI CONFIGURATION"

    case "${1:-status}" in
        status)
            local p; p="$(_aichat_swap status)"
            export MOTHER_AI_PROFILE="$p"
            _mlog AI "Active → $p"
            ;;
        *)
            _aichat_swap "$@"
            local p; p="$(_aichat_swap status)"
            export MOTHER_AI_PROFILE="$p"
            _mlog AI "Now → $p"
            ;;
    esac
}

alias ai='mother-ai'
alias aiswap='_aichat_swap'

#######################################################
# MODERN TOOLING
#######################################################
_cmd eza && alias ls='eza -a --icons'
_cmd bat && alias cat='bat'
_cmd rg  && alias grep='rg'

#######################################################
# LEGACY COMPATIBILITY
#######################################################
alias mkcd='cargo-mkcd'
alias up='cargo-up'

alias g='git'
alias gs='hyper-status'
alias ga='hyper-add'
alias gc='hyper-commit'
alias gp='hyper-push'

alias ll='cargo-list'
alias iplocal='net-local'
alias ippublic='net-public'

alias reload='mother-reload'
alias zero='clear'
alias path='echo -e ${PATH//:/\n}'

#######################################################
# PROMPT
#######################################################
if _cmd starship; then
    eval "$(starship init bash)"
else
    PS1='[\u@\h \W] $ '
fi

#######################################################
# BOOT
#######################################################
[[ -z "$MOTHER_SILENT" ]] && mother-status
