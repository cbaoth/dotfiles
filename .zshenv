# ~/.zlogout: executed by zsh(1) initially.
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > zlogin / .zlogout
#
# https://manpages.ubuntu.com/manpages/bionic//man1/zsh.1.html
# 1. Commands are first read from /etc/zsh/zshenv; this cannot be overridden
# 2. Commands are then read from $ZDOTDIR/.zshenv.
# 3. If the shell is a login shell, commands are read from /etc/zsh/zprofile and then $ZDOTDIR/.zprofile.
# 4. Then, if the shell is interactive, commands are read from /etc/zsh/zshrc and then $ZDOTDIR/.zshrc.
# 5. Finally, if the shell is a login shell, /etc/zsh/zlogin and $ZDOTDIR/.zlogin are read.
#
# https://zsh.sourceforge.io/Intro/intro_3.html
# .zshenv is sourced on all invocations of the shell, unless the -f option is set.
# It should contain commands to set the command search path, plus other important environment variables.
# .zshenv should not contain commands that produce output or assume the shell is attached to a tty.
#
# Author:  cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc zshenv shell-script

# Source environment settings common to all my shells
source ~/.myenv

# If ZDOTDIR is not set, then the value of $HOME is (usually) used but ZDOTDIR stays unset.
# Since we specifically use it in some places (primarily .zshrc) it should always be set here.
#export ZDOTDIR="$HOME/.zsh"
export ZDOTDIR="$HOME"

