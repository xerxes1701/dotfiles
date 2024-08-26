-- A plugin to improve your rust experience in neovim.
-- https://github.com/simrat39/rust-tools.nvim

return {
	"simrat39/rust-tools.nvim",
	config = function()
		local rt = require("rust-tools")

		rt.setup({
			server = {
				on_attach = function(_, buf)
					vim.keymap.set(
						"n",
						"<leader>ch",
						rt.hover_actions.hover_actions,
						{ buffer = buf, desc = "rust hover action" }
					)
					vim.keymap.set(
						"n",
						"<leader>cr",
						rt.code_action_group.code_action_group,
						{ buffer = buf, desc = "rust hover action" }
					)
				end,
			},
		})
	end,
}
