-- highlight/find TODO/HACK/BUG comments (integrated into telescope, see telescope.lua)
-- https://github.com/folke/todo-comments.nvim

return {
	"folke/todo-comments.nvim",
	commit = "31e3c38",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	config = function()
		require("todo-comments").setup({})
	end,
}
