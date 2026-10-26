-- Neovim config: the parts of ~/.vimrc that still matter in nvim.
-- Neovim already defaults to most of the old vimrc (nocompatible,
-- backspace=indent,eol,start, incsearch, ruler, showcmd, syntax on, ...),
-- so only the differences are set here.

local opt = vim.opt

-- search: case insensitive (regex like /^# works out of the box, magic is on)
opt.ignorecase = true

-- indentation: 4 spaces
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true

-- no backup / swap files
opt.backup = false
opt.writebackup = false
opt.swapfile = false

-- disable mouse (nvim default: mouse=nvi), keeps terminal selection/copy
opt.mouse = ""

opt.textwidth = 0     -- don't wrap words
opt.showmatch = true  -- briefly jump to matching bracket
opt.autowrite = true  -- save before :next, :make, ...

-- buffer next/prev, redo
vim.keymap.set("", "<C-n>", "<Cmd>bn<CR>")
vim.keymap.set("", "<C-p>", "<Cmd>bp<CR>")
vim.keymap.set("", "<C-u>", "<Cmd>redo<CR>")

-- Home/End: tmux-256color sends \e[1~ / \e[4~, which nvim decodes as the
-- VT220 keys <Find> / <Select> (inserted literally in insert mode)
for _, mode in ipairs({ "", "i", "c" }) do
  vim.keymap.set(mode, "<Find>", "<Home>")
  vim.keymap.set(mode, "<Select>", "<End>")
end
