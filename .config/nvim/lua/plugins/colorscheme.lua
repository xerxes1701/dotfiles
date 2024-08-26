-- the colorscheme should be available when starting Neovim
-- https://github.com/catppuccin/nvim

return {
	"catppuccin/nvim",
	name = "catppuccin",
	tag = "v1.9.0",
	priority = 1000,
	config = function()
		require("catppuccin").setup({
			transparent_background = true,
			term_colors = true,
			integrations = {
				bufferline = true,
				cmp = true,
				gitsigns = true,
				mason = true,
				notify = true,
				nvimtree = true,
				symbols_outline = true,
				telescope = {
					enabled = true,
				},
				treesitter = true,
				treesitter_context = true,
				which_key = true,
			},
		})
		vim.cmd.colorscheme("catppuccin")
	end,
}
