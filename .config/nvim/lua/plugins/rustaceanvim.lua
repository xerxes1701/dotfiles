return {
	"mrcjkb/rustaceanvim",
	commit = "88575b9",
	version = "^6", -- Recommended
	lazy = false, -- This plugin is already lazy
	init = function()
		-- rustaceanvim is configured via the `vim.g.rustaceanvim` global, which
		-- must be set before the plugin loads.
		vim.g.rustaceanvim = {
			server = {
				settings = {
					["rust-analyzer"] = {
						-- CodeLens: inline actionable annotations above items.
						-- run/debug/implementations/updateTest are rust-analyzer
						-- defaults; the references.* lenses are opt-in.
						lens = {
							enable = true,
							run = { enable = true },
							debug = { enable = true },
							implementations = { enable = true },
							updateTest = { enable = true },
							references = {
								adt = { enable = true },
								enumVariant = { enable = true },
								method = { enable = true },
								trait = { enable = true },
							},
						},
						-- Inlay hints: what rust-analyzer offers; display is toggled
						-- on the client side (see lspconfig.lua LspAttach).
						inlayHints = {
							closureReturnTypeHints = { enable = "always" },
							lifetimeElisionHints = { enable = "skip_trivial", useParameterNames = true },
							parameterHints = { enable = true },
							typeHints = { enable = true },
						},
					},
				},
			},
		}
	end,
}
