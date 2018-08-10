# ~/.zsh/functions-freebsd.zsh: FreeBSD functions

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zshrc bashrc shell-script freebsd

rpm-extract () {
  [ -z "$1" ] &&\
    echo-usage "rpm-extract rpm-file\n  chown root:wheel and copy manually to /compat/linux\n  find /compat/linux -uid $USER | xargs sudo chown root:wheel" &&\
    return 1
  rpm2cpio "$1" | cpio -idv
}
