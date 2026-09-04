-- installer / manager for LSP server, linter, formatter, ...
-- https://github.com/williamboman/mason-lspconfig.nvim

return {
	"williamboman/mason.nvim",
	commit = "44d1e90",
	dependencies = {
		{ "williamboman/mason-lspconfig.nvim", commit = "a5671269a1ddfa7790cdf97c14e600e269da550f" },
		{ "WhoIsSethDaniel/mason-tool-installer.nvim", commit = "443f1ef" },
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
			},
			-- rustaceanvim owns the rust-analyzer client (clippy-on-save, debugging,
			-- code lens, macro expand) and roslyn.nvim owns the C# client. Excluding
			-- them here stops mason-lspconfig from auto-starting a second, redundant
			-- client -> no more duplicate diagnostics. `roslyn_ls` is defensive: the
			-- Crashdummyy `roslyn` package declares no `neovim.lspconfig` field, so
			-- nothing maps to it today, but installing mason-org's
			-- `roslyn-language-server` later would otherwise start a rival client.
			automatic_enable = {
				exclude = { "rust_analyzer", "roslyn_ls" },
			},
		})

		require("mason-tool-installer").setup({
			ensure_installed = {
				-- c# language server, driven by roslyn.nvim. Comes from the
				-- Crashdummyy registry above, which tracks the version vscode
				-- ships; mason-org's `roslyn-language-server` lags behind.
				"roslyn",
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
