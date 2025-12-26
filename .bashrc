# ~/.bashrc: bash(1) - The individual per-interactive-shell startup file.
# This file is read and executed by bash for non-login interactive shells.
# It is not read by bash login shells (.bash_profile is used for that).

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: bashrc shell-script

# To view this file correctly use fold-mode for emacs and add the following
# line to your .emacs:
#   (folding-add-to-marks-list 'shell-script-mode "# {{{ " "# }}}" nil t)

# {{{ = ENVIRONMENT (INTERACTIVE SHELL) ======================================
# Source environment settings common to all my shells
[[ -f ~/.common_profile ]] && source ~/.common_profile

# {{{ - ENV STATE ------------------------------------------------------------
# This is already done in ~/.common_profile, but kept here for reference or to
# override if needed
#export OS=$(uname | tr '[A-Z]' '[a-z]')
#[[ -z "${HOST-}" ]] && export HOST=$HOSTNAME
# }}} - ENV STATE ------------------------------------------------------------

# {{{ - CUSTOM VARIABLES -----------------------------------------------------
# globally raise (but never lower) the default debug level of cl::p_dbg
# this is set in ~/.common_profile to be available for all shells, override
# here if needed
#export DBG_LVL=0
# }}} - CUSTOM VARIABLES -----------------------------------------------------
# }}} = ENVIRONMENT (ALL SHELLS) =============================================
# {{{ - PRIVACY --------------------------------------------------------------
# private session
#export HISTFILE="" # don't create shell history file
#export SAVEHIST=0 # set shell history file limit to zero
# shared session
export HISTSIZE=10000 # set in-memory history limit
export SAVEHIST=10000 # set history file limit
export HISTFILE="$HOME/.bhistory" # set history file (default: ~/.bash_history)
# }}} - PRIVACY --------------------------------------------------------------
# }}} = ENVIRONMENT (INTERACTIVE SHELL) ======================================

# {{{ = PROMPT ===============================================================
#export LANG=C
export PS1="\[\e[0;37m\](\w)\[\\033[0;39m\]
[\[\\033[0;34m\]\u\[\\033[0;39m\]@\[\\033[4;38m\]\h\[\\033[0;39m\]]\$ "
# }}} = PROMPT ===============================================================

# {{{ = INCLUDES =============================================================
source $HOME/.aliases
# }}} = INCLUDES =============================================================

# {{{ = FINAL EXECUTIONS =====================================================
# {{{ - X WINDOWS ------------------------------------------------------------
# Ensure that Gnome Key Ring allows access to SSH keys
# Disabled e.g. in favor of KeePassXC (Secret Service Integration)
#
# are we in a x-windows session?
if [[ -n "${DESKTOP_SESSION-}" ]]; then
    # is gnome-keyring-daemon availlable? use it as ssh agent
    if command -v gnome-keyring-daemon 2>&1 > /dev/null; then
        # start unless already running
        if [[ -n "${GNOME_KEYRING_PID-}" ]]; then
            export $(gnome-keyring-daemon --start --components=ssh) #--components=pkcs11,secret,ssh)
            # SSH_AGENT_PID required to stop xinitrc-common from starting ssh-agent
            export SSH_AGENT_PID=${GNOME_KEYRING_PID:-gnome}
        fi
    fi
fi
# }}} - X WINDOWS ------------------------------------------------------------
# {{{ - MOTD -----------------------------------------------------------------
# print welcome message (if top-level shell)
if (($SHLVL == 1)); then
    printf -P "%B%F{white}Welcome to %F{green}%m %F{white}running %F{green}$(uname -srm)%F{white}"
    # on %F{green}#%l%f%b"
    printf -P "%B%F{white}Uptime:%b%F{green}$(uptime)\e%f"
fi
# }}} - MOTD -----------------------------------------------------------------
# }}} = FINAL EXECUTIONS =====================================================
