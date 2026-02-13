# ~/.zsh/aliases-motoko.zsh: Motoko host aliases
# code: language=zsh insertSpaces=true tabSize=2
# keywords: zsh dotfile zshrc aliases shell shell-script
# author: Andreas Weyer

# {{{ - APPS -----------------------------------------------------------------
alias comfyenv="source ~/comfy-env/bin/activate"
alias comfy="command -v comfy-cli >& /dev/null || comfyenv && comfy-cli"
alias comfyu="comfy update"
alias comfyun="comfy node update all"
alias comfyua="comfyu && comfyun"
alias comfyui="comfy launch"
# }}} - APPS -----------------------------------------------------------------

return 0
