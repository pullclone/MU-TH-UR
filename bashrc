# ~/.bashrc - MU/TH/UR Integrated Shell
# Maintainer: Ethan P. Kelley
# Version: MU/TH/UR Phase 2 (aiswap v1.2.2 integrated)

#######################################################
# INTERACTIVE GUARD
#######################################################
[[ $- != *i* ]] && return

#######################################################
# SYSTEM BASE
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

__history_prompt_command() { history -a; }
case ";$PROMPT_COMMAND;" in
  *";__history_prompt_command;"*) ;;
  *) PROMPT_COMMAND="__history_prompt_command;$PROMPT_COMMAND" ;;
esac

#######################################################
# ENV
#######################################################
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export VISUAL="${VISUAL:-micro}"
export EDITOR="${EDITOR:-$VISUAL}"

#######################################################
# PATH
#######################################################
__path_prepend(){ [[ -d "$1" ]] && [[ ":$PATH:" != *":$1:"* ]] && PATH="$1:$PATH"; }
__path_prepend "$HOME/.local/bin"
__path_prepend "$HOME/.cargo/bin"
export PATH

#######################################################
# START DIR
#######################################################
[[ -d "$HOME/Dev" ]] && cd "$HOME/Dev"

#######################################################
# SAFE OPS
#######################################################
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

#######################################################
# MU/TH/UR VISUAL CORE
#######################################################
BLUE='\e[34m'; BOLD='\e[1m'; DIM='\e[2m'; RESET='\e[0m'

_cmd_exists(){ command -v "$1" >/dev/null 2>&1; }

_mother_banner(){
  echo -e "${BLUE}${BOLD}[MU/TH/UR] >> ${1:-STATUS}${RESET}"
}

mother-status(){
  _mother_banner "SYSTEM STATUS"
  echo -e "${BLUE}Host: $(hostname)${RESET}"
  echo -e "${BLUE}Uptime: $(uptime -p 2>/dev/null || echo N/A)${RESET}"
}

mother-disconnect(){
  sudo -k
  _mother_banner "UPLINK TERMINATED"
}

alias mthr-off='mother-disconnect'
alias mu-status='mother-status'

#######################################################
# SSH AGENT (WSL FIXED)
#######################################################
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh/sockets"

export SSH_AUTH_SOCK="$HOME/.ssh/sockets/ssh-agent.socket"

start_ssh_agent(){
  rm -f "$SSH_AUTH_SOCK"
  ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null
}

ssh-add -l >/dev/null 2>&1
case $? in
  2) start_ssh_agent ;;
esac

ssh-add -l >/dev/null 2>&1
case $? in
  1) [[ -f "$HOME/.ssh/id_ed25519" ]] && ssh-add "$HOME/.ssh/id_ed25519" ;;
esac

#######################################################
# AI ENVIRONMENT BINDING
#######################################################
export AICHAT_CONF_DIR="${XDG_CONFIG_HOME}/aichat"
export AICHAT_ACTIVE="$(cat "$AICHAT_CONF_DIR/current" 2>/dev/null || echo unknown)"

ai-status(){
  _mother_banner "AI PROFILE"
  echo -e "${BLUE}Active: $AICHAT_ACTIVE${RESET}"
}

#######################################################
# AISWAP v1.2.2
#######################################################
###############################################################################
# _aichat_swap v1.2.2
#
# Fixes:
# - Restores short flags (-h, -l, -s, -d)
# - Fixes command normalization layer
# - Preserves full swap + alias system
###############################################################################
_aichat_swap() {
    local VERSION="1.2.2"

    # Paths
    local BASE_DIR="${AICHAT_CONF_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/aichat}"
    local DIR="$BASE_DIR"
    local BACKUP_DIR="$DIR/backups"
    local LOCK_DIR="$DIR/.swap.lock.d"
    local CURRENT_FILE="$DIR/current"
    local ALIAS_FILE="$DIR/aliases"

    # Profiles
    local IDS=(c g m o)
    local NAMES=(altostrat alpha lechat stargate)

    # Flags
    local DRY_RUN=false
    local VERBOSE=false
    local TMPFILE=""
    local HAVE_LOCK=false

    ###########################################################################
    # Helpers
    ###########################################################################
    _msg() {
        local type="$1"; shift
        local color=0 out=1 sym=""
        case "$type" in
            err) color=1; out=2; sym="❌ " ;;
            warn) color=3; out=2; sym="⚠️  " ;;
            ok) color=2; sym="✅ " ;;
            info) color=4 ;;
            dry) color=5; sym="🔍 " ;;
        esac
        if [[ -t $out ]] && command -v tput >/dev/null 2>&1; then
            printf "%b\n" "$(tput setaf $color)${sym}$*$(tput sgr0)" >&$out
        else
            printf "%s\n" "${sym}$*" >&$out
        fi
    }

    _exec() {
        local cmd="$1"; shift
        if $DRY_RUN || $VERBOSE; then
            local debug="$cmd"
            for arg in "$@"; do debug="$debug $(printf "%q" "$arg")"; done
            $DRY_RUN && _msg dry "[DRY-RUN] $debug" && return 0
            _msg info "$debug"
        fi
        "$cmd" "$@"
    }

    _get_editor() {
        [[ -n "$EDITOR" ]] && { echo "$EDITOR"; return; }
        local editors=(code subl micro nano vim vi)
        for ed in "${editors[@]}"; do
            command -v "$ed" >/dev/null && { echo "$ed"; return; }
        done
        echo "vi"
    }

    _get_name() {
        local target="$1" i
        for i in "${!IDS[@]}"; do
            [[ "${IDS[$i]}" == "$target" ]] && echo "${NAMES[$i]}" && return
        done
        echo "unknown"
    }

    ###########################################################################
    # Alias Control Plane
    ###########################################################################
    _alias_list() { [[ -f "$ALIAS_FILE" ]] && cat "$ALIAS_FILE"; }

    _alias_write() {
        local tmp
        tmp=$(mktemp "$DIR/.aliases.tmp.XXXXXX") || return 1
        cat > "$tmp"
        mv "$tmp" "$ALIAS_FILE"
    }

    _rebuild_aliases() {
        [[ -f "$ALIAS_FILE" ]] || return
        while read -r id name; do
            [[ -z "$id" || -z "$name" ]] && continue
            alias "$name"="_aichat_swap $id"
        done < "$ALIAS_FILE"
        alias aiswap="_aichat_swap"
    }

    ###########################################################################
    # Locking
    ###########################################################################
    _acquire_lock() {
        local retries=0 max=6 stale=30
        while (( retries < max )); do
            mkdir "$LOCK_DIR" 2>/dev/null && return 0
            sleep 0.5; ((retries++))
        done
        return 1
    }

    _cleanup() {
        [[ -n "$TMPFILE" && -f "$TMPFILE" ]] && rm -f "$TMPFILE"
        $HAVE_LOCK && rmdir "$LOCK_DIR" 2>/dev/null
    }

    ###########################################################################
    # HELP
    ###########################################################################
    _show_help() {
        cat <<EOF
aiswap v$VERSION

Usage:
  aiswap [options] <command|profile_id>

Commands:
  list, ls, -l     List profiles
  status, -s       Show active profile
  diff, -d <id>    Diff profile
  edit             Edit config
  init             Initialize
  alias <cmd>      Alias control
  help, -h         Show help
EOF
    }

    ###########################################################################
    # ARG PARSING
    ###########################################################################
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run) DRY_RUN=true ;;
            -v|--verbose) VERBOSE=true ;;
            -h) args+=("help") ;;
            -l) args+=("list") ;;
            -s) args+=("status") ;;
            -d) args+=("diff") ;;
            *) args+=("$1") ;;
        esac
        shift
    done
    set -- "${args[@]}"

    local cmd="${1:-status}"
    cmd=$(printf "%s" "$cmd" | tr '[:upper:]' '[:lower:]')

    ###########################################################################
    # COMMAND NORMALIZATION
    ###########################################################################
    case "$cmd" in
        ls) cmd="list" ;;
        stat) cmd="status" ;;
    esac

    ###########################################################################
    # Alias Commands
    ###########################################################################
    if [[ "$cmd" == "alias" ]]; then
        case "${2:-list}" in
            list) _alias_list ;;
            add)
                { _alias_list; printf "%s %s\n" "$3" "$4"; } | _alias_write
                ;;
            remove)
                grep -vE "[[:space:]]$3$" "$ALIAS_FILE" | _alias_write
                ;;
            edit) "$(_get_editor)" "$ALIAS_FILE" ;;
            rebuild) _rebuild_aliases ;;
        esac
        return
    fi

    ###########################################################################
    # Core Commands
    ###########################################################################
    case "$cmd" in
        help) _show_help; return ;;
        list)
            local current=""
            [[ -f "$CURRENT_FILE" ]] && current=$(head -n1 "$CURRENT_FILE")
            for i in "${!IDS[@]}"; do
                local mark=" "
                [[ "${IDS[$i]}" == "$current" ]] && mark="*"
                printf "%s [%s] %s\n" "$mark" "${IDS[$i]}" "${NAMES[$i]}"
            done
            return ;;
        status)
            [[ -f "$CURRENT_FILE" ]] && _msg info "Active: $(_get_name "$(cat "$CURRENT_FILE")")"
            return ;;
        edit)
            "$(_get_editor)" "$DIR/config.yaml"
            return ;;
        diff)
            diff -u "$DIR/config.yaml" "$DIR/$2.config.yaml"
            return ;;
        init)
            _exec mkdir -p "$DIR" "$BACKUP_DIR"
            touch "$DIR/config.yaml"
            for id in "${IDS[@]}"; do touch "$DIR/$id.config.yaml"; done
            return ;;
    esac

    ###########################################################################
    # Swap Logic
    ###########################################################################
    local target="$cmd"
    local current=""
    [[ -f "$CURRENT_FILE" ]] && current=$(head -n1 "$CURRENT_FILE")

    [[ "$target" == "$current" ]] && { _msg ok "Already active."; return; }

    _acquire_lock || { _msg err "Lock failed."; return 1; }
    HAVE_LOCK=true
    trap '_cleanup' EXIT

    local src="$DIR/$target.config.yaml"
    [[ ! -f "$src" ]] && { _msg err "Missing profile."; return 1; }

    TMPFILE=$(mktemp "$DIR/.tmp.XXXXXX") || return 1
    cp "$src" "$TMPFILE"
    mv "$TMPFILE" "$DIR/config.yaml"
    echo "$target" > "$CURRENT_FILE"

    _msg ok "Switched → $(_get_name "$target")"
}

#######################################################
# AISWAP AUTO-LOAD
#######################################################
if [[ $- == *i* ]]; then
  _aichat_swap alias rebuild 2>/dev/null
fi

#######################################################
# MODERN TOOLING
#######################################################
command -v eza >/dev/null && alias ls='eza -a --icons'
command -v bat >/dev/null && alias cat='bat'

#######################################################
# GIT
#######################################################
alias g='git'
alias gs='git status'
alias gp='git push'

#######################################################
# STARTUP
#######################################################
command -v starship >/dev/null && eval "$(starship init bash)"
command -v zoxide >/dev/null && eval "$(zoxide init bash)"

#######################################################
# MU/TH/UR BOOT
#######################################################
muther-motd(){
  echo -e "${BLUE}${BOLD}MU/TH/UR 6000 ONLINE${RESET}"
}

muther-motd
