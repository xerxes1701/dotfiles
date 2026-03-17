-- status line
-- https://github.com/nvim-lualine/lualine.nvim

return {
	"nvim-lualine/lualine.nvim",
	commit = "47f91c4",
	dependencies = "nvim-web-devicons",
	event = "VimEnter",
	config = function()
		local lazy_status = require("lazy.status")

		require("lualine").setup({
			options = {
				theme = "catppuccin",
			},
			sections = {
				lualine_x = {
					{
						function()
							return lazy_status.updates() or ""
						end,
						lazy_status.has_updates,
						color = { fg = "#ff9e64" },
					},
					{ "encoding" },
					{ "fileformat" },
					{ "filetype" },
				},
			},
		})
	end,
}
