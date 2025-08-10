-- parsing, ast, syntax highlighting, indentation, ...
-- https://github.com/nvim-treesitter/nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter.configs").setup({
			auto_install = true,
			modules = {},
			ignore_install = {},
			ensure_installed = {
				"lua",
				"vim",
				"vimdoc",
				"javascript",
				"html",
				"json",
				"toml",
				"xml",
				"rust",
				"c_sharp",
				"markdown",
				"markdown_inline",
			},
			sync_install = false,
			highlight = {
				enable = true,
			},
			indent = {
				enable = true,
			},
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "<A-v>",
					node_incremental = "<A-v>",
					scope_incremental = false,
					node_decremental = "<A-V>",
				},
			},
		})
	end,
}
