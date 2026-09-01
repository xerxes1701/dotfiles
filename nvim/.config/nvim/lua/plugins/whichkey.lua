-- displays key-bindins, mark infos, and reqister infos
-- https://github.com/folke/which-key.nvim

return {
	"folke/which-key.nvim",
	commit = "6c1584e",
	tag = "v3.13.2",
	dependencies = { "nvim-web-devicons" },
	event = "VeryLazy",
	opts = {
		delay = 1000,
		spec = {
			{ "<leader>l", group = "lsp" },
			{ "<leader>lS", group = "server" },
			{ "<leader>ld", desc = "diagnostics hydra" },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = true })
			end,
			desc = "Buffer local keymaps (which-key)",
		},
		--[[
    When Open:
    (") displays registers
    (') or (`) displays marks
    --]]
	},
}
