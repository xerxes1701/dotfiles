-- quickly navigate between files via quick lists
-- https://github.com/ThePrimeagen/harpoon

return {
	"ThePrimeagen/harpoon",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	config = function()
		local harpoon = require("harpoon")
		local mark = require("harpoon.mark")
		local ui = require("harpoon.ui")

		vim.keymap.set("n", "<leader>ha", mark.add_file, { desc = "harpoon add file" })
		vim.keymap.set("n", "<leader>hq", ui.toggle_quick_menu, { desc = "harpoon show files" })

		for i = 1, 9 do
			vim.keymap.set("n", "" .. i, function()
				ui.nav_file(i)
			end, { desc = "harpoon goto file " .. i })
		end

		harpoon.setup({})
	end,
}
