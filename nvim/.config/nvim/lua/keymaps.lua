local keymap = vim.api.nvim_set_keymap

-- Move selected line / block of text in visual mode
keymap("x", "J", ":move '>+1<CR>gv=gv", { noremap = true, silent = true })
keymap("x", "K", ":move '<-2<CR>gv=gv", { noremap = true, silent = true })

-- Cancel search highlighting with ESC
keymap("n", "<ESC>", ":nohlsearch<Bar>:echo<CR>", { noremap = true, silent = true })

-- Navigation between panes and splits, and resizing them, lives in
-- lua/plugins/smart-splits.lua: <C-hjkl> and <C-arrows> have to cross the
-- boundary into tmux or herdr panes, which a plain wincmd cannot do.
-- <C-\> stays here because it is level-local in every app.
keymap("n", "<C-\\>", "<C-w>p", { desc = "goto previous pane/split", noremap = true, silent = true })

-- clipboard copy/paste
keymap("n", "<leader>y", '"+y', { desc = "yank to clipboard" })
keymap("v", "<leader>y", '"+y', { desc = "yank to clipboard" })
keymap("n", "<leader>p", '"+p', { desc = "yank to clipboard" })
keymap("v", "<leader>p", '"+p', { desc = "yank to clipboard" })
keymap("n", "d", '"_d', { noremap = true })
keymap("n", "c", '"_c', { noremap = true })
keymap("n", "<leader>d", "d", { noremap = true })
keymap("n", "<leader>c", "c", { noremap = true })

-- increment / decrement numbers
keymap("n", "<leader>+", "<C-a>", { desc = "increment number" })
keymap("n", "<leader>-", "<C-x>", { desc = "decrement number" })

-- Paste over currently selected text without yanking it
keymap("v", "<leader>p", '"_dP', { noremap = true, silent = true })
keymap("n", "x", '"_x', { noremap = true, silent = true })
keymap("n", "Q", "<nop>", { noremap = true, silent = true })

-- Better indent
keymap("v", "<", "<gv", { noremap = true, silent = true })
keymap("v", ">", ">gv", { noremap = true, silent = true })
keymap("n", "<", "<<", { noremap = true, silent = true })
keymap("n", ">", ">>", { noremap = true, silent = true })

-- open Lazy plugin manager
keymap("n", "<leader>L", "<cmd>Lazy<CR>", { noremap = true, silent = true })

-- split management
keymap("n", "<leader>sv", "<cmd>vsplit<CR>", { desc = "split vertical", noremap = true, silent = true })
keymap("n", "<leader>s-", "<cmd>split<CR>", { desc = "split horizontal", noremap = true, silent = true })
keymap("n", "<leader>se", "<C-w>=<CR>", { desc = "split equalize size", noremap = true, silent = true })
keymap("n", "<leader>sx", "<cmd>close<CR>", { desc = "split close", noremap = true, silent = true })
keymap("n", "<leader>so", "<C-w>w", { desc = "split cycle next", noremap = true, silent = true })

-- tab management
keymap("n", "<leader>tc", "<cmd>tabnew<CR>", { desc = "tab open new" })
keymap("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "tab open new with current file" })
keymap("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "tab close" })
keymap("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "tab move next" })
keymap("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "tab move prev" })
keymap("n", "<leader><Tab>", "<cmd>tabn<CR>", { desc = "tab move next", noremap = true, silent = true })
keymap("n", "<leader><S-Tab>", "<cmd>tabp<CR>", { desc = "tab move next", noremap = true, silent = true })

-- Jump straight to a tab, the leader-layer twin of prefix+1..9 in tmux and herdr.
for i = 1, 9 do
	keymap("n", "<leader>" .. i, "<cmd>tabnext " .. i .. "<CR>", { desc = "tab goto " .. i, noremap = true, silent = true })
end

-- terminal mode
keymap("t", "<Esc>", "<C-\\><C-N>", { desc = "exit terminal insert mode", noremap = true })
