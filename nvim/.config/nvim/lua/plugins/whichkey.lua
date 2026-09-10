-- displays key-bindins, mark infos, and reqister infos
-- https://github.com/folke/which-key.nvim

return {
	"folke/which-key.nvim",
	commit = "6c1584e",
	dependencies = { "nvim-web-devicons" },
	event = "VeryLazy",
	opts = {
		delay = 1000,
		spec = {
			{ "<leader>l", group = "lsp" },
			{ "<leader>lS", group = "server" },
			{ "<leader>ld", desc = "diagnostics hydra" },
			{ "<leader>T", group = "typst" },
			-- The three levels of the unified navigation scheme. The letter
			-- after the group matches the key after the tmux/herdr prefix.
			{ "<leader>s", group = "split (pane level)" },
			{ "<leader>t", group = "tab level" },
			{ "<leader>w", group = "session (workspace level)" },
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
