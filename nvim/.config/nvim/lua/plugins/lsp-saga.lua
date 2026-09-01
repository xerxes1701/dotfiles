return {
	"nvimdev/lspsaga.nvim",
	commit = "562d972",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	after = "nvim-lspconfig",
	config = function()
		require("lspsaga").setup({})

		vim.keymap.set("n", "<leader>la", ":Lspsaga code_action<CR>", { desc = "code action" })

		vim.keymap.set("n", "<F14>", ":Lspsaga diagnostic_jump_next<CR>", { desc = "go to next diagnostic" })
		vim.keymap.set("n", "<C-F14>", ":Lspsaga diagnostic_jump_prev<CR>", { desc = "go to prev diagnostic" })
	end,
}
