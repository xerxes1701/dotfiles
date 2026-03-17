return {
	"rachartier/tiny-glimmer.nvim",
	commit = "932e6c2",
	event = "VeryLazy",
	priority = 10, -- Low priority to catch other plugins' keybindings
	config = function()
		require("tiny-glimmer").setup()
	end,
}
