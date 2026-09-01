-- automatic session management
-- https://github.com/rmagatti/auto-session

return {
	"rmagatti/auto-session",
	commit = "79ef41274354a486cf4f100a7adf4a7575802ccf",
	lazy = false,
	dependencies = {
		"nvim-telescope/telescope.nvim", -- Only needed if you want to use sesssion lens
	},
	config = function()
		require("auto-session").setup({
			auto_session_suppress_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
		})
	end,
}
