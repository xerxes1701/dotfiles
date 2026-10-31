-- .NET workflows (run, test, debug, nuget, solutions) and the C# / Razor LSP
-- https://github.com/GustavEikaas/easy-dotnet.nvim

return {
	"GustavEikaas/easy-dotnet.nvim",
	commit = "0a8cfb96e40b985921e6613f31f75811e31b8edf",
	dependencies = {
		{ "nvim-lua/plenary.nvim", commit = "b9fd522" },
		{ "nvim-telescope/telescope.nvim" },
	},
	config = function()
		require("easy-dotnet").setup({
			-- easy-dotnet's built-in Roslyn client, "easy_dotnet", is the only C#
			-- client. roslyn.nvim used to run a second Roslyn beside it, and every
			-- diagnostic showed twice. The server is the `roslyn-language-server`
			-- dotnet global tool, which easy-dotnet installs when it is missing;
			-- update it with `dotnet-easydotnet roslyn update`.
			lsp = {
				-- When on, easy-dotnet calls vim.lsp.codelens.enable(true) on every
				-- BufEnter, CursorHold and InsertLeave, which undoes the hydra's
				-- codelens toggle. Neovim 0.12 refreshes enabled lenses on its own,
				-- and lspconfig.lua's LspAttach handler enables them.
				auto_refresh_codelens = false,
				config = {
					-- Deep-merged over easy-dotnet's own defaults. Roslyn emits no
					-- inlay hints and no reference code lens unless they are switched
					-- on here. The shared LspAttach handler in lspconfig.lua then
					-- renders them for this client like it does for any other.
					settings = {
						["csharp|background_analysis"] = {
							dotnet_analyzer_diagnostics_scope = "fullSolution",
							dotnet_compiler_diagnostics_scope = "fullSolution",
						},
						["csharp|inlay_hints"] = {
							csharp_enable_inlay_hints_for_implicit_object_creation = true,
							csharp_enable_inlay_hints_for_implicit_variable_types = true,
							csharp_enable_inlay_hints_for_lambda_parameter_types = true,
							csharp_enable_inlay_hints_for_types = true,
							dotnet_enable_inlay_hints_for_indexer_parameters = true,
							dotnet_enable_inlay_hints_for_literal_parameters = true,
							dotnet_enable_inlay_hints_for_object_creation_parameters = true,
							dotnet_enable_inlay_hints_for_other_parameters = true,
							dotnet_enable_inlay_hints_for_parameters = true,
						},
						["csharp|code_lens"] = {
							dotnet_enable_references_code_lens = true,
						},
						["csharp|completion"] = {
							dotnet_show_name_completion_suggestions = true,
							dotnet_show_completion_items_from_unimported_namespaces = true,
							dotnet_provide_regex_completions = true,
						},
						["csharp|symbol_search"] = {
							dotnet_search_reference_assemblies = true,
						},
					},
				},
			},
		})
	end,
}
