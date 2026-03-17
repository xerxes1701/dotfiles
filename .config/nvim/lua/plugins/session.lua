-- automatic session management
-- https://github.com/rmagatti/auto-session

return {
	"rmagatti/auto-session",
	commit = "5dd9600",
	tag = "v2.5.0",
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
