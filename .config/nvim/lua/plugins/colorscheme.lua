-- the colorscheme should be available when starting Neovim
-- https://github.com/catppuccin/nvim

return { 
  "catppuccin/nvim", 
  name = "catppuccin", 
  tag = 'v1.9.0',
  priority = 1000,
  config = function()
    require('catppuccin').setup({
      transparent_background = true,
    })
    vim.cmd.colorscheme('catppuccin')
  end,
}
