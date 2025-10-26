return {
	"ahkohd/difft.nvim",
	keys = {
		{
			"<leader>cD",
			function()
				if Difft.is_visible() then
					Difft.hide()
				else
					Difft.diff()
				end
			end,
		},
	},
	config = function()
		require("difft").setup({
			command = "GIT_EXTERNAL_DIFF='difft --color=always' git diff",
			layout = "float",
		})
	end,
}
