return {
	"echasnovski/mini.nvim",
	version = "*",
	config = function()
		require("mini.ai").setup()
		require("mini.operators").setup()
		--		require("mini.completion").setup()
	end,
}
