# ~/.zsh/zshrc-freebsd.zsh: Linux zshrc

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zshrc shell-script linux

# == EXECUTE =================================================================
# -- SHELL -------------------------------------------------------------------
#setterm -blength 0

# -- WINDOWS SUBSYSTEM LINUX -------------------------------------------------
if $IS_WSL; then
  [ -f $HOME/weasel-pageant/weasel-pageant ] \
    && eval $(/$HOME/weasel-pageant/weasel-pageant -r) > /dev/null
  export DISPLAY=:0
fi
