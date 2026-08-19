-- Automatically configures lua-language-server for your Neovim config, Neovim runtime and plugin directories
-- https://github.com/folke/neodev.nvim

return {
	"folke/lazydev.nvim",
	commit = "ff2cbcb",
	ft = "lua", -- only load on lua files
	opts = {
		library = {
			"lazy.nvim",
			"noice.nvim",
			-- See the configuration section for more details
			-- Load luvit types when the `vim.uv` word is found
			{
				path = "${3rd}/luv/library",
				words = { "vim%.uv" },
			},
		},
	},
}
