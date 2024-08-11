-- tab headers
-- https://github.com/akinsho/bufferline.nvim

return {
  'akinsho/bufferline.nvim',
  tag = 'v4.7.0',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require('bufferline').setup({
      options = {
        mode = 'tabs',
        separator_style = 'thin',
      },
      highlights = require("catppuccin.groups.integrations.bufferline").get(),
    })
  end,
}
