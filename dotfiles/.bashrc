# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.bashrc: startup file for interactive non-login bash shells.
#
# interactive non-login shell: .bashrc
# login shell: .bash_profile (or .bash_login or .profile, first found) > .bash_logout

# {{{ = ENVIRONMENT (INTERACTIVE SHELL) ======================================
# {{{ - COMMON ENV VARIABLE --------------------------------------------------
# Source common shell environment (same for zsh and bash)
if [[ -f ~/.common_env ]]; then
  # shellcheck source=/dev/null
  source ~/.common_env
else
  echo "Warning: ~/.common_env not found, some potentially crucial environment settings or functionality may be missing!" >&2
fi

# globally raise (but never lower) the default debug level of cl::p_dbg -t
#export DEBUG_LVL=3
# }}} - COMMON ENV VARIABLE --------------------------------------------------

# {{{ - COMMON OPTIONS & COMMONS ---------------------------------------------
if [[ -f ~/lib/commons.sh ]]; then
  # shellcheck source=/dev/null
  source ~/lib/commons.sh
else
  echo "Warning: ~/lib/commons.sh not found, some potentially crucial environment settings or functionality may be missing!" >&2
fi
# }}} - COMMON OPTIONS & COMMONS ---------------------------------------------
# }}} = ENVIRONMENT (ALL SHELLS) =============================================
# {{{ - SECURITY & PRIVACY RELATED -------------------------------------------
# private session
#export HISTFILE="" # don't create shell history file
#export SAVEHIST=0 # set shell history file limit to zero
# shared session
export HISTSIZE=10000 # set in-memory history limit
export SAVEHIST=10000 # set history file limit
export HISTFILE="$HOME/.bhistory" # set history file (default: ~/.bash_history)
# }}} - SECURITY & PRIVACY RELATED -------------------------------------------

# {{{ - PROMPT ---------------------------------------------------------------
export PS1="\[\e[0;37m\](\w)\[\\033[0;39m\]
[\[\\033[0;34m\]\u\[\\033[0;39m\]@\[\\033[4;38m\]\h\[\\033[0;39m\]]\$ "
# }}} - PROMPT ---------------------------------------------------------------
# }}} = ENVIRONMENT (INTERACTIVE SHELL) ======================================

# {{{ = SOURCE CUSTOM ALIASES AND FUNCTIONS ==================================
# shellcheck source=/dev/null
source "$HOME/.aliases"
# }}} = SOURCE CUSTOM ALIASES AND FUNCTIONS ==================================

# {{{ = FINAL EXECUTIONS =====================================================
# {{{ - X WINDOWS / WAYLAND --------------------------------------------------
# Ensure that Gnome Key Ring allows access to SSH keys
# Disabled e.g. in favor of KeePassXC (Secret Service Integration)
#
# are we in a x-windows session?
# if [[ -n "${DESKTOP_SESSION-}" ]]; then
#     # is gnome-keyring-daemon availlable? use it as ssh agent
#     if command -v gnome-keyring-daemon 2>&1 > /dev/null; then
#         # start unless already running
#         if [[ -n "${GNOME_KEYRING_PID-}" ]]; then
#             export "$(gnome-keyring-daemon --start --components=ssh)" #--components=pkcs11,secret,ssh)
#             # SSH_AGENT_PID required to stop xinitrc-common from starting ssh-agent
#             export SSH_AGENT_PID=${GNOME_KEYRING_PID:-gnome}
#         fi
#     fi
# fi
# }}} - X WINDOWS / WAYLAND --------------------------------------------------
# {{{ - SOURCE/INITIALIZE DEV TOOLS ------------------------------------------
# Load NodeJS version manager if installed
# - https://nodejs.org/en/download
# - https://github.com/nvm-sh/nvm?tab=readme-ov-file#installing-and-updating
if [[ -d "$HOME/.config/nvm" ]]; then
  export NVM_DIR="$HOME/.config/nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
  fi
  if [[ -s "$NVM_DIR/bash_completion" ]]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/bash_completion"
  fi
fi

# anaconda3 / miniconda3
# - https://www.anaconda.com/docs/getting-started/miniconda/main
# - https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
if [[ -f "$HOME/anaconda3/bin/conda" ]]; then
  _MY_CONDA="$HOME/anaconda3"
elif [[ -f "$HOME/miniconda3/bin/conda" ]]; then
  _MY_CONDA="$HOME/miniconda3"
fi
if [[ -n "${_MY_CONDA:-}" ]]; then
  if __conda_setup="$("$_MY_CONDA/bin/conda" 'shell.bash' 'hook' 2>/dev/null)"; then
    eval "$__conda_setup"
  else
    if [[ -f "$_MY_CONDA/etc/profile.d/conda.sh" ]]; then
      # shellcheck source=/dev/null
      source "$_MY_CONDA/etc/profile.d/conda.sh"
    else
      export PATH="$_MY_CONDA/bin:$PATH"
    fi
  fi
  unset __conda_setup
fi

# determinate-nix > official nix CLI
if command -v determinate-nixd >/dev/null 2>&1; then
  # activate determinate-nixd auto completion subcommand
  # https://docs.determinate.systems/determinate-nix/#determinate-nixd-completion
  eval "$(determinate-nixd completion bash)"
else
  # source Nix profile (official version, see below for Determinate Nix)
  if ! command -v nix >/dev/null 2>&1 && [[ -f ~/.nix-profile/etc/profile.d/nix.sh ]]; then
    # shellcheck source=/dev/null
    source ~/.nix-profile/etc/profile.d/nix.sh
  fi
fi

# # angular CLI autocompletion, if ng is avaiable
# if command -v ng >/dev/null 2>&1; then
#   source <(ng completion script)
# fi
# }}} - SOURCE/INITIALIZE DEV TOOLS ------------------------------------------

# {{{ - MOTD -----------------------------------------------------------------
# Print MOTD messages only for top-level shells (no sub-shells, su, tmux, etc.)
if (( SHLVL == 1 )); then
  # Print welcome message for login shells (includes ssh sessions) or docker containers
  if shopt -q login_shell || [[ -n "${IS_DOCKER:-}" ]]; then
    printf "%s\n" "$(cl::fx b)$(cl::fx white)Welcome to $(cl::fx green)$(hostname) $(cl::fx white)running $(cl::fx green)$(uname -srm)$(cl::fx reset)"
  fi
  printf "%s\n" "$(cl::fx b)$(cl::fx white)Time: $(cl::fx green)$(date '+%a %Y-%m-%d %T')$(cl::fx white), Uptime: $(cl::fx green)$(uptime -p)$(cl::fx white) since $(cl::fx green)$(uptime -s)$(cl::fx white)$(cl::fx reset)"
fi
# }}} - MOTD -----------------------------------------------------------------
# }}} = FINAL EXECUTIONS =====================================================
