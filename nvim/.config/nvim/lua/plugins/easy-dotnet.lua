return {
	"GustavEikaas/easy-dotnet.nvim",
	commit = "0a8cfb96e40b985921e6613f31f75811e31b8edf",
	dependencies = {
		{ "nvim-lua/plenary.nvim", commit = "b9fd522" },
		{ "nvim-telescope/telescope.nvim" },
	},
	config = function()
		require("easy-dotnet").setup()
	end,
}
