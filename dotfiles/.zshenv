# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zshenv: executed by zsh(1) before other startup files.
#
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > .zlogin (.zlogout on exit)
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
# .zshenv should NOT contain commands that produce output or assume the shell is attached to a tty.

# Source common shell environment (same for zsh and bash)
if [[ -f ~/.common_env ]]; then
  # shellcheck source=/dev/null
  source ~/.common_env
else
  echo "Warning: ~/.common_env not found, some potentially crucial environment settings or functionality may be missing!" >&2
fi

# Deduplicate path variables (zsh-specific, safe if variables are unset)
typeset -U PATH path
typeset -U LD_LIBRARY_PATH

# If ZDOTDIR is not set, then the value of $HOME is (usually) used but ZDOTDIR stays unset.
# Since we specifically use it in some places (primarily .zshrc) it should always be set here.
#export ZDOTDIR="$HOME/.zsh"
export ZDOTDIR="$HOME"
