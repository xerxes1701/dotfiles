return {
	"echasnovski/mini.nvim",
	commit = "1345d191bb3da9c7b0e977f4387c5761f9bff68d",
	config = function()
		require("mini.ai").setup()
		require("mini.operators").setup()
		require("mini.splitjoin").setup()
		--		require("mini.completion").setup()
	end,
}
