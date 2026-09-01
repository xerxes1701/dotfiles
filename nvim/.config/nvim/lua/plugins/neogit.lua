-- git ui
-- https://github.com/NeogitOrg/neogit

return {
	"NeogitOrg/neogit",
	commit = "37e0f22a2345bad1bffe01b31970885882f46275",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"sindrets/diffview.nvim",
		"nvim-telescope/telescope.nvim",
	},
	config = function()
		require("neogit").setup({
			integrations = {
				diffview = true,
			},
		})
	end,
	keys = {
		{ "<leader>gg", "<cmd>Neogit<CR>", "open Neo Git" },
	},
}
