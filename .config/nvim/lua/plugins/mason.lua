-- installer / manager for LSP server, linter, formatter, ...
-- https://github.com/williamboman/mason-lspconfig.nvim

return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		require("mason").setup({})

		require("mason-lspconfig").setup({
			ensure_installed = {
				"lua_ls", -- lua
				"tsserver", -- typescript
				"markdown_oxide", -- markdown
			},
		})

		require("mason-tool-installer").setup({
			ensure_installed = {
				"prettier",
				"stylua", -- lua
				"vale", -- markdown
				"eslint_d", -- javascript, typescript, ...
			},
		})
	end,
}
