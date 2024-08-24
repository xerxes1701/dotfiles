-- generic autocompletion based on current buffer, file system paths, and snippets
-- https://github.com/hrsh7th/nvim-cmp

return {
  'hrsh7th/nvim-cmp',
  event = 'InsertEnter',
  dependencies = {
    'hrsh7th/cmp-buffer', -- source for text in buffer
    'hrsh7th/cmp-path', -- source for file system paths
    {
      'L3MON4D3/LuaSnip',
      version = 'v2.*',
      build = 'make install_jsregexp',
    },
    'saadparwaiz1/cmp_luasnip', -- source for lua snippest
    'rafamadriz/friendly-snippets', -- useful snippets
    'onsails/lspkind.nvim', -- vs-code like pictograms
  },
  config = function()
    local cmp = require('cmp')
    local luasnip = require('luasnip')
    local lspkind = require('lspkind')

    -- load vs-code style snippets from installed plugins (friendly-snippets)
    require('luasnip.loaders.from_vscode').lazy_load()

    cmp.setup({
      snippets = { 
        -- configure how nvim interacts with snippets engine
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ['<C-k>'] = cmp.mapping.select_prev_item(),
        ['<C-j>'] = cmp.mapping.select_next_item(),
        ['<C-f>'] = cmp.mapping.scroll_docs(-4),
        ['<C-b>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(), -- show suggestions
        ['<C-e>'] = cmp.mapping.abort(), 
        ['<CR>'] = cmp.mapping.confirm({ select = false }),
        ['<Tab>'] = cmp.mapping.confirm({ select = false }),
      }),
      sources = cmp.config.sources({
        { name = 'luasnip' }, -- snippest
        { name = 'buffer' }, -- text in buffer
        { name = 'path' }, -- file system pahts
      }),
      formatting = {
        format = lspkind.cmp_format({
          maxwith = 50,
          ellipsis_char = '...',
        }),
      },
    })
  end,
}
