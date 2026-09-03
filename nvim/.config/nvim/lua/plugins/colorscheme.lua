-- the colorscheme should be available when starting Neovim
-- https://github.com/catppuccin/nvim

return {
	"catppuccin/nvim",
	name = "catppuccin",
	commit = "605b4603797de970e9f3a4238c199c850da03186",
	priority = 1000,
	config = function()
		require("catppuccin").setup({
			transparent_background = true,
			term_colors = true,
			integrations = {
				blink_cmp = true,
				gitsigns = true,
				mason = true,
				notify = true,
				nvimtree = true,
				symbols_outline = true,
				telescope = {
					enabled = true,
				},
				treesitter_context = true,
				which_key = true,
			},
		})
		vim.cmd.colorscheme("catppuccin")
	end,
}
