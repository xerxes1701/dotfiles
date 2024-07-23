-- displays key-bindins, mark infos, and reqister infos
-- https://github.com/folke/which-key.nvim

return {
  "folke/which-key.nvim",
  dependencies = { 'nvim-web-devicons' },
  event = 'VeryLazy',
  opts = {
  },
  keys = {
    {
      '<leader>?', 
      function() require('which-key').show({ global = true, }) end,
      desc = 'Buffer local keymaps (which-key)',
    },
    --[[
    When Open:
    (") displays registers
    (') or (`) displays marks
    --]]
  },
}
