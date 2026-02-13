# ~/.zsh/aliases-saito.zsh: Saito host aliases
# code: language=zsh insertSpaces=true tabSize=2
# keywords: zsh dotfile zshrc aliases shell shell-script
# author: Andreas Weyer

# {{{ - SYSTEM ---------------------------------------------------------------
alias open-stash="sudo cryptsetup open /dev/md1 stash"
alias close-stash="sudo cryptsetup close stash"
alias mount-stash="sudo cryptsetup open /dev/md1 stash && sudo mount /dev/mapper/stash /media/stash"
alias umount-stash="sudo umount /media/stash; sudo cryptsetup close stash"
# }}} - SYSTEM ---------------------------------------------------------------

return 0
