-- git change indicator
-- https://github.com/lewis6991/gitsigns.nvim

return {
  'lewis6991/gitsigns.nvim',
  tag = 'v0.9.0',
  config = function()
    local gitsigns = require('gitsigns')

    gitsigns.setup({ 
    })

    vim.keymap.set('n', '<leader>hs', '<cmd>Gitsigns stage_hunk<cr>')
    vim.keymap.set('n', '<leader>hu', '<cmd>Gitsigns undo_stage_hunk<cr>') 
    vim.keymap.set('n', '<leader>hp', '<cmd>Gitsigns preview_hunk<cr>') 
    vim.keymap.set('n', '<leader>hd', '<cmd>Gitsigns diffthis<cr>') 
    -- vim.keymap.set('n', '<leader>hD', function() gitsigns.diffthis('~') end) 
  end,
}
