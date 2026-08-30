-- fuzzy finder
-- https://github.com/nvim-telescope/telescope.nvim

return {
	"nvim-telescope/telescope.nvim",
	commit = "5255aa27c422de944791318024167ad5d40aad20",
	tag = "v0.2.2",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		"folke/todo-comments.nvim",
		"ThePrimeagen/harpoon",
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		telescope.setup({
			defaults = {
				path_display = { "smart" },
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous,
						["<C-j>"] = actions.move_selection_next,
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
					},
				},
			},
			pickers = {
				keymaps = {
					show_plug = false,
				},
			},
		})

		-- load native fzf extension
		telescope.load_extension("harpoon")
	end,
	keys = {
		{ "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "fuzzy find live grep" },
		{ "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "fuzzy find recent" },
		{ "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "fuzzy find files" },
		{ "<leader>fF", "<cmd>Telescope find_files hidden=true<cr>", desc = "fuzzy find hidden files" },
		{ "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "fuzzy find buffers" },
		{ "<leader>f?", "<cmd>Telescope help_tags<cr>", desc = "fuzzy find help tags" },
		{ "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "fuzzy find keymaps" },
		{ "<leader>fK", "<cmd>lua require('keymap_registry').pick()<cr>", desc = "fuzzy find keymaps by plugin" },
		{ "<leader>ft", "<cmd>TodoTelescope<CR>", desc = "fuzzy find help tags" },
		{ "<leader>fh", "<cmd>Telescope harpoon marks<CR>", desc = "fuzzy find harpoon marks" },
		{ "<leader>fj", "<cmd>Telescope jumplist<CR>", desc = "fuzzy find jumplist entries" },
	},
}
