print(vim.g.mapleader)

return {
  -- the colorscheme should be available when starting Neovim
  {
    "sainnhe/everforest",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      -- load the colorscheme here
      vim.cmd([[colorscheme everforest]])
    end,
  },
  {
    'goolord/alpha-nvim',
    config = function ()
        require('alpha').setup(require('alpha.themes.dashboard').config)
    end
  },
  {
    'nvim-lua/plenary.nvim'
  },
   { 
    'nvim-telescope/telescope.nvim', 
    tag = '0.1.1',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys =
    {
      {'<leader>fg', "<cmd>Telescope live_grep<cr>", desc = "Live grep"},
      {'<leader>ff', "<cmd>Telescope find_files<cr>", desc = "Find file"},
      {'<leader>fb', "<cmd>Telescope buffers<cr>", desc = "Find buffer"},
      {'<leader>fh', "<cmd>Telescope help_tags<cr>", desc = "Find tag"},
    },
  }
}
