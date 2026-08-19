return {
	"echasnovski/mini.nvim",
	commit = "a995fe9",
	version = "*",
	config = function()
		require("mini.ai").setup()
		require("mini.operators").setup()
		require("mini.splitjoin").setup()
		--		require("mini.completion").setup()
	end,
}
