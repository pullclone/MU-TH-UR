# ~/.bashrc — MU/TH/UR Structured Operator Shell
# Maintainer: Ethan P. Kelley
# Rebuilt: 2026-04-07 (aiswap v1.2.5 + SSH Double-Prompt Fix)

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
# SSH AGENT (WSL-OPTIMAL SOCKET MODEL)
#######################################################
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh/sockets" 2>/dev/null

export SSH_AUTH_SOCK="$HOME/.ssh/sockets/ssh-agent.socket"

start_ssh_agent(){
    pkill -u "$USER" ssh-agent 2>/dev/null
    rm -f "$SSH_AUTH_SOCK"
    eval "$(ssh-agent -s -a "$SSH_AUTH_SOCK")" >/dev/null
}

# Only invoke SSH unlock sequence ONCE per session tree to prevent double-prompts
if [[ -z "$_MU_SSH_AUTH_ATTEMPTED" ]]; then
    export _MU_SSH_AUTH_ATTEMPTED=1

    ssh-add -l >/dev/null 2>&1
    if [ $? -eq 2 ]; then
        start_ssh_agent
    fi

    if ! ssh-add -l >/dev/null 2>&1; then
        [[ -f "$HOME/.ssh/id_ed25519" ]] && ssh-add "$HOME/.ssh/id_ed25519" </dev/tty
    fi
fi

#######################################################
# AICHAT CORE (v1.2.5 — dynamic alias merging)
#######################################################
_aichat_swap() {
    local VERSION="1.2.5"
    local BASE_DIR="${AICHAT_CONF_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/aichat}"
    local DIR="$BASE_DIR"
    local BACKUP_DIR="$DIR/backups"
    local LOCK_DIR="$DIR/.swap.lock.d"
    local CURRENT_FILE="$DIR/current"
    local ALIAS_FILE="$DIR/aliases"

    # Default Profiles
    local IDS=(c g m o)
    local NAMES=(altostrat alpha lechat stargate)
    
    local DRY_RUN=false VERBOSE=false TMPFILE="" HAVE_LOCK=false

    # Dynamically merge file-based aliases into engine memory (Bash 3.2 Portable)
    _load_profiles() {
        [[ -f "$ALIAS_FILE" ]] || return 0
        local new_ids=() new_names=()
        local i j found

        # Load defaults
        for i in "${!IDS[@]}"; do
            new_ids+=("${IDS[$i]}")
            new_names+=("${NAMES[$i]}")
        done

        # Merge overrides / additions
        while read -r id name; do
            # Skip empty lines or comments
            [[ -z "$id" || -z "$name" || "$id" == \#* ]] && continue
            found=false
            for j in "${!new_ids[@]}"; do
                if [[ "${new_ids[$j]}" == "$id" ]]; then
                    new_names[$j]="$name"
                    found=true
                    break
                fi
            done
            if ! $found; then
                new_ids+=("$id")
                new_names+=("$name")
            fi
        done < "$ALIAS_FILE"

        IDS=("${new_ids[@]}")
        NAMES=("${new_names[@]}")
    }
    
    # Initialize engine state
    _load_profiles

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
            command -v "$ed" >/dev/null 2>&1 && { echo "$ed"; return; }
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
        alias aiswap="_aichat_swap"
        local i
        # Since _load_profiles already merged defaults and file data, we just map them all
        for i in "${!IDS[@]}"; do
            alias "${NAMES[$i]}"="_aichat_swap ${IDS[$i]}"
        done
    }

    ###########################################################################
    # Locking & Cleanup
    ###########################################################################
    _acquire_lock() {
        mkdir -p "$DIR" 2>/dev/null
        local retries=0 max=6 stale=30
        while (( retries < max )); do
            if mkdir "$LOCK_DIR" 2>/dev/null; then
                return 0
            fi

            local now mtime=0
            now=$(date +%s)
            if stat -c %Y "$LOCK_DIR" >/dev/null 2>&1; then
                mtime=$(stat -c %Y "$LOCK_DIR")
            elif stat -f %m "$LOCK_DIR" >/dev/null 2>&1; then
                mtime=$(stat -f %m "$LOCK_DIR")
            fi

            if (( mtime > 0 && now - mtime > stale )); then
                _msg warn "Stale lock detected — reclaiming"
                rmdir "$LOCK_DIR" 2>/dev/null
                continue
            fi

            sleep 0.5
            ((retries++))
        done
        return 1
    }

    _cleanup() {
        [[ -n "$TMPFILE" && -f "$TMPFILE" ]] && rm -f "$TMPFILE" 2>/dev/null
        if $HAVE_LOCK; then
            rmdir "$LOCK_DIR" 2>/dev/null
            HAVE_LOCK=false
        fi
        trap - INT TERM 2>/dev/null
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
                _msg ok "Alias added: $4 → $3"
                ;;
            remove)
                grep -vE "[[:space:]]$3$" "$ALIAS_FILE" | _alias_write
                _msg ok "Alias removed: $3"
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
            [[ -f "$CURRENT_FILE" ]] && current=$(head -n1 "$CURRENT_FILE" 2>/dev/null | tr -cd '[:alnum:]')
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
            # Now dynamically touches custom profiles as well
            for id in "${IDS[@]}"; do touch "$DIR/$id.config.yaml"; done
            _msg ok "Initialization complete."
            return ;;
    esac

    ###########################################################################
    # Swap Logic
    ###########################################################################
    local target="$cmd"
    local current=""
    [[ -f "$CURRENT_FILE" ]] && current=$(head -n1 "$CURRENT_FILE" 2>/dev/null | tr -cd '[:alnum:]')

    local valid_target=false i
    for i in "${!IDS[@]}"; do [[ "$target" == "${IDS[$i]}" ]] && valid_target=true && break; done

    if ! $valid_target; then
        _msg err "Unknown profile or command: '$target'"
        _msg info "Use 'list' to see options."
        return 1
    fi

    if [[ "$target" == "$current" ]]; then
        _msg ok "Profile [$target] already active."
        return 0
    fi

    if $DRY_RUN; then
        _msg dry "Would lock, save current state, and swap to: $(_get_name "$target") ($target)"
        return 0
    fi

    # Acquire Lock (Strict cleanup routing from here down)
    _acquire_lock || { _msg err "Lock failed (busy?)."; return 1; }
    HAVE_LOCK=true
    trap '_cleanup; return 1' INT TERM

    # ---------------------------------------------------------
    # State Deduction & Backup 
    # ---------------------------------------------------------
    if [[ -z "$current" ]] && [[ -f "$DIR/config.yaml" ]]; then
        _msg warn "Unknown state. Fingerprinting..."
        local id match_id=""
        for id in "${IDS[@]}"; do
            if cmp -s "$DIR/config.yaml" "$DIR/$id.config.yaml" 2>/dev/null; then
                match_id="$id"; break
            fi
        done
        
        if [[ -n "$match_id" ]]; then
            current="$match_id"
            echo "$current" > "$CURRENT_FILE"
        else
            local ts; ts=$(date +%Y%m%d_%H%M%S)
            _msg warn "No match found. Backing up active config..."
            mkdir -p "$BACKUP_DIR" 2>/dev/null
            cp -p "$DIR/config.yaml" "$BACKUP_DIR/unknown_$ts.yaml" 2>/dev/null
            find "$BACKUP_DIR" -type f -mtime +7 -delete 2>/dev/null
        fi
    fi

    if [[ -n "$current" ]]; then
        local storage_file="$DIR/$current.config.yaml"
        if ! cmp -s "$DIR/config.yaml" "$storage_file" 2>/dev/null; then
            cp -p "$DIR/config.yaml" "$storage_file" 2>/dev/null
        fi
    fi

    # ---------------------------------------------------------
    # Perform Atomic Swap
    # ---------------------------------------------------------
    local src="$DIR/$target.config.yaml"
    if [[ ! -f "$src" ]]; then
        _msg err "Missing profile: $src"
        _cleanup
        return 1
    fi

    # BUGFIX: Prevent 0-byte profile overrides
    if [[ ! -s "$src" && -s "$DIR/config.yaml" ]]; then
        _msg warn "Target profile [$target] is empty. Adopting active config data..."
        cp -p "$DIR/config.yaml" "$src" 2>/dev/null
    fi

    TMPFILE=$(mktemp "$DIR/.tmp.XXXXXX") || {
        _msg err "Failed to create temp file."
        _cleanup
        return 1
    }
    
    cp -p "$src" "$TMPFILE"
    mv "$TMPFILE" "$DIR/config.yaml"
    echo "$target" > "$CURRENT_FILE"

    _msg ok "Switched → $(_get_name "$target")"
    
    _cleanup
    return 0
}

#######################################################
# AICHAT INIT + ENV BINDING
#######################################################
if [[ $- == *i* ]]; then
    _aichat_swap alias rebuild 2>/dev/null

    # Sync environment variable on boot
    _MU_AICHAT_CUR="${AICHAT_CONF_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/aichat}/current"
    if [[ -f "$_MU_AICHAT_CUR" ]]; then
        export MOTHER_AI_PROFILE="$(cat "$_MU_AICHAT_CUR" 2>/dev/null | tr -cd '[:alnum:]')"
    fi
fi

#######################################################
# MU/TH/UR AI INTERFACE
#######################################################
mother-ai(){
    _mbanner "AI CONFIGURATION"

    # Pass all commands down to aichat_swap
    _aichat_swap "$@"

    # Silently resync MOTHER_AI_PROFILE after any operation
    local cur="${AICHAT_CONF_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/aichat}/current"
    if [[ -f "$cur" ]]; then
        export MOTHER_AI_PROFILE="$(cat "$cur" 2>/dev/null | tr -cd '[:alnum:]')"
    fi
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
