-- file explorer
-- https://github.com/nvim-tree/nvim-tree.lua

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

return {
  "nvim-tree/nvim-tree.lua",
  tag = 'v1.6.0',
  lazy = false,
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    require("nvim-tree").setup {}
  end,
  keys = {
    { '<leader>ee', '<cmd>NvimTreeToggle<CR>', desc = 'toggle file explorer' },
    { '<leader>ef', '<cmd>NvimTreeFindFileToggle<CR>', desc = 'toggle file explorer search' },
    { '<leader>ec', '<cmd>NvimTreeCollapse<CR>', desc = 'collapse file explorer' },
    { '<leader>ef', '<cmd>NvimTreeRefresh<CR>', desc = 'refresh file explorer' },
  },
}
