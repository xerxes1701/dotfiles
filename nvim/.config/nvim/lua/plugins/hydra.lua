return {
	"nvimtools/hydra.nvim",
	commit = "8c4a9f6",
	dependencies = {
		"nvim-treesitter/nvim-treesitter-textobjects",
	},
	init = function()
		vim.keymap.set("n", "S", "<Nop>")
	end,
	config = function()
		require("config.hydra-codenav").setup()
		require("config.hydra-diagnostics").setup()
	end,
}
