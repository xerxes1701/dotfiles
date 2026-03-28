return {
	"nvimtools/hydra.nvim",
	commit = "8c4a9f6",
	dependencies = {
		"nvim-treesitter/nvim-treesitter-textobjects",
	},
	init = function()
		vim.keymap.set("n", "s", "<Nop>")
	end,
	config = function()
		local Hydra = require("hydra")

		local tsmove_goto_next_start = function(obj)
			local ts_move = require("nvim-treesitter.textobjects.move")
			return function()
				ts_move.goto_next_start(obj)
			end
		end

		local tsmove_goto_prev_start = function(obj)
			local ts_move = require("nvim-treesitter.textobjects.move")
			return function()
				ts_move.goto_previous_start(obj)
			end
		end

		Hydra({
			name = "treewalker",
			mode = "n",
			body = "s",

			-- these are explained below
			hint = [[ treewalker ]],
			config = {
				color = "pink",
				timeout = false,
				invoke_on_body = true,
			},
			heads = {
				{ "k", "<cmd>Treewalker Up<cr>", { silent = true } },
				{ "l", "<cmd>Treewalker Right<cr>", { silent = true } },
				{ "j", "<cmd>Treewalker Down<cr>", { silent = true } },
				{ "h", "<cmd>Treewalker Left<cr>", { silent = true } },

				{ "==", tsmove_goto_next_start("@assignment.outer"), {} },
				{ "=+", tsmove_goto_prev_start("@assignment.outer"), {} },
				{ "++", tsmove_goto_prev_start("@assignment.outer"), {} },

				{ "=l", tsmove_goto_next_start("@assignment.lhs"), {} },
				{ "=L", tsmove_goto_prev_start("@assignment.lhs"), {} },
				{ "+L", tsmove_goto_prev_start("@assignment.lhs"), {} },

				{ "=r", tsmove_goto_next_start("@assignment.rhs"), {} },
				{ "=R", tsmove_goto_prev_start("@assignment.rhs"), {} },
				{ "+R", tsmove_goto_prev_start("@assignment.rhs"), {} },

				{ "n", tsmove_goto_next_start("@number.inner"), {} },
				{ "N", tsmove_goto_prev_start("@number.inner"), {} },

				{ "c", tsmove_goto_next_start("@comment.outer"), {} },
				{ "C", tsmove_goto_prev_start("@comment.outer"), {} },

				{ "t", tsmove_goto_next_start("@class.outer"), {} },
				{ "T", tsmove_goto_prev_start("@class.outer"), {} },

				{ "m", tsmove_goto_next_start("@function.outer"), {} },
				{ "M", tsmove_goto_prev_start("@function.outer"), {} },

				{ "a", tsmove_goto_next_start("@parameter.outer"), {} },
				{ "A", tsmove_goto_prev_start("@parameter.outer"), {} },

				{ "p", tsmove_goto_next_start("@parameter.inner"), {} },
				{ "P", tsmove_goto_prev_start("@parameter.inner"), {} },

				-- { "g", tsmove_goto_next_start("@parameter.outer"), {} },
				-- { "G", tsmove_goto_prev_start("@parameter.outer"), {} },

				{ "r", tsmove_goto_next_start("@return.outer"), {} },
				{ "R", tsmove_goto_prev_start("@return.outer"), {} },

				{ "b", tsmove_goto_next_start("@block.outer"), {} },
				{ "B", tsmove_goto_prev_start("@block.outer"), {} },

				{ "v", tsmove_goto_next_start("@block.outer"), {} },
				{ "V", tsmove_goto_prev_start("@block.inner"), {} },

				{ "i", tsmove_goto_next_start("@conditional.outer"), {} },
				{ "I", tsmove_goto_prev_start("@conditional.outer"), {} },

				{ "o", tsmove_goto_next_start("@conditional.inner"), {} },
				{ "O", tsmove_goto_prev_start("@conditional.inner"), {} },

				{ "f", tsmove_goto_next_start("@call.outer"), {} },
				{ "F", tsmove_goto_prev_start("@call.outer"), {} },

				{ "w", tsmove_goto_next_start("@loop.outer"), {} },
				{ "W", tsmove_goto_prev_start("@loop.outer"), {} },
			},
		})
	end,
}
