return {
	"GustavEikaas/easy-dotnet.nvim",
	commit = "e1d6f89",
	dependencies = {
		{ "nvim-lua/plenary.nvim", commit = "b9fd522" },
		{ "nvim-telescope/telescope.nvim" },
	},
	config = function()
		require("easy-dotnet").setup()
	end,
}
