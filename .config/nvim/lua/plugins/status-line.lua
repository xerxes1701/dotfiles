-- status line
-- https://github.com/nvim-lualine/lualine.nvim

return {
  'nvim-lualine/lualine.nvim',
  dependencies = 'nvim-web-devicons',
  event = 'VimEnter',
  config = function()
    local lazy_status = require('lazy.status')

    require('lualine').setup({
      sections = {
        lualine_x = {
          {
            lazy_status.updates,
            lazy_status.has_updates,
            color = { fg = '#ff9e64' },
          },
          { 'encoding' },
          { 'fileformat' },
          { 'filetype' },
        }
      }
    })
  end,
}
