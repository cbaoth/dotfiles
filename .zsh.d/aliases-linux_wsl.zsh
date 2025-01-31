# ~/.zsh/aliases-linux_wsl.zsh: Windows Subsystem Linux aliases

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc  shell-script linux

# Alias to copy to Windows clipboard (plain and unicode version)
alias wclipset='clip.exe'
alias wclipsetu='iconv -f utf-8 -t utf-16le | clip.exe'

# Alias to get content from Windows clipboard (plain and unicode version)
alias wclipget='powershell.exe Get-Clipboard'
alias wclipgetu='powershell.exe Get-Clipboard | iconv -f utf-16le -t utf-8'
