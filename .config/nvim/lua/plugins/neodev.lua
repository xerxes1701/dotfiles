-- Automatically configures lua-language-server for your Neovim config, Neovim runtime and plugin directories
-- https://github.com/folke/neodev.nvim

return {
	"folke/neodev.nvim",
	config = function()
		-- IMPORTANT: make sure to setup neodev BEFORE lspconfig
		require("neodev").setup({
			library = {
				plugins = { "nvim-dap-ui" },
				types = true,
			},
		})
	end,
}
