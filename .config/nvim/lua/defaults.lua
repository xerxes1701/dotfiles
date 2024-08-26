local api = vim.api
local g = vim.g
local opt = vim.opt

-- api.nvim_set_keymap("", "<Space>", "<Nop>", { noremap = true, silent = true })

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
g.mapleader = " "
g.maplocalleader = "\\"

-- search
opt.hlsearch = true --Set highlight on search
opt.ignorecase = true --Case insensitive searching unless /C or capital in search (`smartcase=true`)
opt.smartcase = true -- Smart case: use case sensitive search if search-text contains capital case

-- autocompletion
opt.completeopt = {
	"menuone", -- popup even when there's only one match
	"noselect", -- Do not insert text until a selection is made
	"noinsert", -- Do not select, force to select one from the menu
}
vim.opt.shortmess = vim.opt.shortmess + { c = true }
vim.cmd([[
set signcolumn=yes
autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
]])

-- linenumbers / signcolumn
opt.number = true --Make line numbers default
opt.relativenumber = true --Make relative number default
opt.signcolumn = "yes" -- Always show sign column (so it doesn't flicker due to git indicators)

-- tabs / indentation
opt.softtabstop = 2 -- width of 2 when pressing the tab key
opt.tabstop = 2 -- width of 2 for an actul tabstop (would repace N space with a tab char, if `expandtab` was false)
opt.shiftwidth = 2 -- 2 space per indentation level (can differ from tabstop)
opt.expandtab = true -- expand tabs with spaces
opt.autoindent = true -- copy indentation from current line, when starting a new one
opt.smarttab = true -- if `true`, use `shiftwidth` at beginning of a line, otherwise `softtabstop`
opt.breakindent = true --Enable break indent

-- splits
opt.splitright = true -- focus lower split if splitting vertically
opt.splitbelow = true -- focus lower split if splitting horizontally

-- other
opt.scrolloff = 10 -- keep N lines visible over cursor line when scrolling up, and same below when scrolling down
opt.updatetime = 250 --Decrease update time
opt.clipboard = "unnamedplus" -- Access system clipboard
opt.termguicolors = true -- Enable colors in terminal
opt.mouse = "a" --Enable mouse mode
opt.undofile = true --Save undo history
opt.cursorline = true -- highlight current line (where the cursor is)
