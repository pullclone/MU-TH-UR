# ~/.bashrc - MU/TH/UR Integrated Shell
# Maintainer: Ethan P. Kelley
# Version: MU/TH/UR Phase 2 (aiswap v1.2.1 integrated)

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
# AISWAP v1.2.1
#######################################################

# (INSERT EXACT FUNCTION FROM PRIOR RESPONSE HERE)
# NOTE: keep it unmodified for integrity

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
