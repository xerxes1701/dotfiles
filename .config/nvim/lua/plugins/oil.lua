-- manage/edit filesystem-directory like a regular vim buffer
-- https://github.com/stevearc/oil.nvim

return {
  'stevearc/oil.nvim',
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local oil = require('oil')
    oil.setup({
      keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["gv"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
        ["gh"] = { "actions.select", opts = { horizontal = true }, desc = "Open the entry in a horizontal split" },
        ["gt"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
        ["gp"] = "actions.preview",
        ["gq"] = "actions.close",
        ["gr"] = "actions.refresh",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
        ["gs"] = "actions.change_sort",
        ["gx"] = "actions.open_external",
        ["g."] = "actions.toggle_hidden",
        ["g\\"] = "actions.toggle_trash",
      },
    })
    
    local keymap = vim.api.nvim_set_keymap
    keymap('n', '<leader>ed', '<cmd>edit %:p:h<CR>', { desc = "edit current file's directory"})
    keymap('n', '<leader>eD', '<cmd>edit .<CR>', { desc = 'edit current directory'})
  end,
}
