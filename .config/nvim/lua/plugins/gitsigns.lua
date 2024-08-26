-- git change indicator
-- https://github.com/lewis6991/gitsigns.nvim

return {
	"lewis6991/gitsigns.nvim",
	tag = "v0.9.0",
	config = function()
		local gitsigns = require("gitsigns")

		gitsigns.setup({})

		vim.keymap.set("n", "<leader>gs", "<cmd>Gitsigns stage_hunk<cr>")
		vim.keymap.set("n", "<leader>gu", "<cmd>Gitsigns undo_stage_hunk<cr>")
		vim.keymap.set("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<cr>")
		vim.keymap.set("n", "<leader>gd", "<cmd>Gitsigns diffthis<cr>")
		-- vim.keymap.set('n', '<leader>gD', function() gitsigns.diffthis('~') end)
	end,
}
