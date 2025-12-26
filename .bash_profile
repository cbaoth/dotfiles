# ~/.profile: bash(1) - The personal initialization file, executed for login shells
#
# This file is only read and executed by bash in a non-interactive login shell,
# or in login shell invoked with option --login.
# It is not read by bash interactive shells (.bashrc is used for that).
#
# Load order:
# 1. /etc/profile (first existing, this will always be read)
# 2. The first file that is found and readable of the following:
#    ~/.bash_profile
#    ~/.bash_login
#    ~/.profile

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: profile bash shell-script

# Source environment settings common to all my shells
[[ -f ~/.common_profile ]] && source ~/.common_profile
