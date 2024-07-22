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
    'nvim-tree/nvim-web-devicons'
  },
  {
    'goolord/alpha-nvim',
    dependencies = {
	    'nvim-tree/nvim-web-devicons',
	    'nvim-lua/plenary.nvim',
    },
    config = function ()
        require('alpha').setup(require('alpha.themes.theta').config)
    end
  },
  {
    'nvim-lua/plenary.nvim'
  },
  { 
    'nvim-telescope/telescope.nvim', 
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys =
    {
      {'<leader>fg', "<cmd>Telescope live_grep<cr>", desc = "Live grep"},
      {'<leader>ff', "<cmd>Telescope find_files<cr>", desc = "Find file"},
      {'<leader>fb', "<cmd>Telescope buffers<cr>", desc = "Find buffer"},
      {'<leader>fh', "<cmd>Telescope help_tags<cr>", desc = "Find tag"},
    },
  },
  {
	  'sindrets/diffview.nvim',
    keys = {
      { '<leader>gd', ':DiffviewOpen<cr>' },
    },
  },
  {
	  'NeogitOrg/neogit',
	  tag = 'v0.0.1', -- neovim 0.9.x compatible
	  dependencies = {
		  'nvim-lua/plenary.nvim',
		  'sindrets/diffview.nvim',
		  'nvim-telescope/telescope.nvim',
	  },
	  config = function()
		  require("config.neogit").setup()
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = { "lua", "vim", "vimdoc", "javascript", "html" },
        sync_install = false,
        highlight = {
          enable = true,
        },
        indent = {
          enable = true,
        },
      })
    end,
  },
}
