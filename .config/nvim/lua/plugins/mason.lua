-- installer / manager for LSP server, linter, formatter, ...
-- https://github.com/williamboman/mason-lspconfig.nvim

return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		require("mason").setup({
			ui = {
				icons = {
					package_installed = "",
					package_pending = "",
					package_uninstalled = "",
				},
			},
			registries = {
				"github:mason-org/mason-registry",
				"github:Crashdummyy/mason-registry",
			},
		})

		require("mason-lspconfig").setup({
			ensure_installed = {
				"lua_ls", -- lua
				"ts_ls", -- typescript
				"markdown_oxide", -- markdown
				"rust_analyzer", -- rust
				-- "roslyn", -- c# (this like dosn't work but `:MasonInstall` does)
			},
		})

		require("mason-tool-installer").setup({
			ensure_installed = {
				"prettier", -- universal formatter
				"stylua", -- lua formatter
				"vale", -- markdown linter
				"eslint_d", -- javascript/typescript linter
				"codelldb", -- native debugger (c, rust, ...)
				"netcoredbg", -- dotnet debugger (c#, f#, ...)
				"cpptools", -- native debugger (c, rust, ...)
			},
		})
	end,
}
