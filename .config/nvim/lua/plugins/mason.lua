-- installer / manager for LSP server, linter, formatter, ...
-- https://github.com/williamboman/mason-lspconfig.nvim

return {
  'williamboman/mason.nvim',
  dependencies = {
    'williamboman/mason-lspconfig.nvim'
  },
  config = function()
    require('mason').setup({
    })

    require('mason-lspconfig').setup({
      ensure_installed = {
        'lua_ls',
      },
    })
  end,
}
