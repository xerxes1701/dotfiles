-- fuzzy finder 
-- https://github.com/nvim-telescope/telescope.nvim

return { 
  'nvim-telescope/telescope.nvim', 
  tag = '0.1.8',
  dependencies = {
    'nvim-lua/plenary.nvim', 
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    'nvim-tree/nvim-web-devicons',
  },
  config = function()
    local telescope = require('telescope')
    local actions = require('telescope.actions')

    telescope.setup({
      defaults = {
        path_display = { 'smart' },
        mappings = {
          i = {
            ['<C-k>'] = actions.move_selection_previous,
            ['<C-j>'] = actions.move_selection_next,
            ['<C-q>'] = actions.send_selected_to_qflist + actions.open_qflist,
          }
        }
      },
    })
    
    -- load native fzf extension
    telescope.load_extension('fzf')
  end,
  keys =
  {
    {'<leader>fg', "<cmd>Telescope live_grep<cr>", desc = "fuzzy find live grep"},
    {'<leader>fr', "<cmd>Telescope oldfiles<cr>", desc = "fuzzy find recent"},
    {'<leader>ff', "<cmd>Telescope find_files<cr>", desc = "fuzzy find files"},
    {'<leader>fd', "<cmd>Telescope find_files hidden=true<cr>", desc = "fuzzy find hidden files"},
    {'<leader>fb', "<cmd>Telescope buffers<cr>", desc = "fuzzy find buffers"},
    {'<leader>fh', "<cmd>Telescope help_tags<cr>", desc = "fuzzy find help tags"},
  },
}
