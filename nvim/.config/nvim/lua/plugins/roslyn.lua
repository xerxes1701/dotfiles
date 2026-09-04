-- Roslyn LSP plugin for neovim (c#, razor)
-- https://github.com/seblyng/roslyn.nvim

return {
	"seblyng/roslyn.nvim",
	commit = "de9a98d61ed3fd01b5016eea5fe9e32f1a4c7cfb",
	-- The plugin's own `lsp/roslyn.lua` declares these two filetypes.
	ft = { "cs", "razor" },
	---@module 'roslyn.config'
	---@type RoslynNvimConfig
	opts = {
		-- "auto" lets the plugin pick between neovim's watcher and the server's.
		-- Switch to "roslyn" if new or moved files are not picked up.
		filewatching = "auto",
		-- Projects here sit at the root of their repo, so there is no need to
		-- search parent directories for a solution.
		broad_search = false,
		lock_target = false,
	},
	-- `init` and not `config`: the plugin's `plugin/roslyn.lua` calls
	-- `vim.lsp.enable("roslyn")` as soon as lazy.nvim sources it, which happens
	-- before a spec's `config` would run. Registering the settings here means
	-- they are in place before the first client can start. Writing a config
	-- does not read the server's `lsp/roslyn.lua`, so this does not need the
	-- plugin on the runtimepath yet.
	init = function()
		-- Roslyn emits no inlay hints and no reference code lens unless they are
		-- switched on here. The shared LspAttach handler in lspconfig.lua then
		-- renders them for this client like it does for any other.
		vim.lsp.config("roslyn", {
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
		})
	end,
}
