# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/aliases-linux_wsl.zsh: WSL-specific aliases.

# Alias to copy to Windows clipboard (plain and unicode version)
alias wclipset='clip.exe'
alias wclipsetu='iconv -f utf-8 -t utf-16le | clip.exe'

# Alias to get content from Windows clipboard (plain and unicode version)
alias wclipget='powershell.exe Get-Clipboard'
alias wclipgetu='powershell.exe Get-Clipboard | iconv -f utf-16le -t utf-8'

return 0
