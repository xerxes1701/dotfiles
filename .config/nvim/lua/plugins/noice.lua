-- completely replaces the UI for messages, cmdline and the popupmenu.
-- https://github.com/folke/noice.nvim

---@type LazyPluginSpec & { opts: NoiceConfig }
return {
	"folke/noice.nvim",
	event = "VeryLazy",
	opts = { ----@type NoiceConfig?
		cmdline = { enabled = true },
		popupmenu = { enabled = true },
		notify = { enabled = false },
		messages = { enabled = false },
		presets = {
			lsp_doc_border = true,
		},
		lsp = {
			signature = {
				auto_open = {
					enabled = false,
				},
			},
		},
		-- add any options here
	},
	dependencies = {
		-- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
		"MunifTanjim/nui.nvim",
		-- OPTIONAL:
		--   `nvim-notify` is only needed, if you want to use the notification view.
		--   If not available, we use `mini` as the fallback
		"rcarriga/nvim-notify",
	},
}
