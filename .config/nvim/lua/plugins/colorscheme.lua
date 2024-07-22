-- the colorscheme should be available when starting Neovim
-- https://github.com/catppuccin/nvim

return { 
  "catppuccin/nvim", 
  name = "catppuccin", 
  priority = 1000,
  config = function()
    require('catppuccin').setup({
    })
    vim.cmd.colorscheme('catppuccin')
  end,
}
