return {
	"nvimdev/lspsaga.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	after = "nvim-lspconfig",
	config = function()
		require("lspsaga").setup({})
	end,
}
