local keymap = vim.api.nvim_set_keymap

-- Move selected line / block of text in visual mode
keymap("x", "K", ":move '<-2<CR>gv-gv", { noremap = true, silent = true })
keymap("x", "J", ":move '>+1<CR>gv-gv", { noremap = true, silent = true })

-- Cancel search highlighting with ESC
keymap("n", "<ESC>", ":nohlsearch<Bar>:echo<CR>", { noremap = true, silent = true })

-- Navigation between panes
-- keymap("n", "<C-h>", ":wincmd h<CR>", { noremap = true, silent = true, desc = "goto left pane" })
-- keymap("n", "<C-j>", ":wincmd k<CR>", { noremap = true, silent = true, desc = "goto upper pane" })
-- keymap("n", "<C-k>", ":wincmd j<CR>", { noremap = true, silent = true, desc = "goto lower pane" })
-- keymap("n", "<C-l>", ":wincmd l<CR>", { noremap = true, silent = true, desc = "goto right pane" })

-- Resizing panes
keymap("n", "<C-Left>", ":vertical resize +1<CR>", { noremap = true, silent = true })
keymap("n", "<C-Right>", ":vertical resize -1<CR>", { noremap = true, silent = true })
keymap("n", "<C-Up>", ":resize -1<CR>", { noremap = true, silent = true })
keymap("n", "<C-Down>", ":resize +1<CR>", { noremap = true, silent = true })


-- Paste over currently selected text without yanking it
keymap("v", "p", '"_dP', { noremap = true, silent = true })

-- Better indent
keymap("v", "<", "<gv", { noremap = true, silent = true })
keymap("v", ">", ">gv", { noremap = true, silent = true })

-- open Lazy plugin manager
keymap("n", "<leader>ll", "<cmd>Lazy<CR>", { noremap = true, silent = true }) 

-- split management
keymap('n', '<leader>sv', '<cmd>vsplit<CR>', { noremap = true, silent = true })
keymap('n', '<leader>sh', '<cmd>split<CR>', { noremap = true, silent = true })
