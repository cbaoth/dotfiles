# ~/.zsh/aliases-motoko.zsh: Motoko host aliases

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc shell-script freebsd

# {{{ - APPS -----------------------------------------------------------------
alias comfyenv="source ~/comfy-env/bin/activate"
alias comfy="command -v comfy-cli >& /dev/null || comfyenv && comfy-cli"
alias comfyui="comfy launch"
# }}} - APPS -----------------------------------------------------------------

return 0
