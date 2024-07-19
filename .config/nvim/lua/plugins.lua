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
}
