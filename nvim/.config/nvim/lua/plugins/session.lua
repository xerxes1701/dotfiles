-- automatic session management
-- https://github.com/rmagatti/auto-session

return {
	"rmagatti/auto-session",
	commit = "79ef41274354a486cf4f100a7adf4a7575802ccf",
	lazy = false,
	dependencies = {
		"nvim-telescope/telescope.nvim", -- Only needed if you want to use sesssion lens
	},
	-- The <leader>w layer is the nvim twin of prefix+w in tmux and herdr: the
	-- outermost level, where you pick which piece of work you are in.
	keys = {
		{ "<leader>ww", "<cmd>SessionSearch<CR>", desc = "session picker" },
		{ "<leader>wN", "<cmd>SessionSave<CR>", desc = "session save" },
		{ "<leader>wD", "<cmd>SessionDelete<CR>", desc = "session delete" },
	},
	config = function()
		require("auto-session").setup({
			auto_session_suppress_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
		})
	end,
}
