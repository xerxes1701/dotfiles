-- fuzzy finder 
-- https://github.com/nvim-telescope/telescope.nvim

return { 
    'nvim-telescope/telescope.nvim', 
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys =
    {
      {'<leader>fg', "<cmd>Telescope live_grep<cr>", desc = "Live grep"},
      {'<leader>ff', "<cmd>Telescope find_files<cr>", desc = "Find file"},
      {'<leader>fd', "<cmd>Telescope find_files hidden=true<cr>", desc = "Find hidden file"},
      {'<leader>fb', "<cmd>Telescope buffers<cr>", desc = "Find buffer"},
      {'<leader>fh', "<cmd>Telescope help_tags<cr>", desc = "Find tag"},
    },
  }
