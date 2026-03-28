-- parsing, ast, syntax highlighting, indentation, ...
-- https://github.com/nvim-treesitter/nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	dependencies = {
		"nvim-treesitter/nvim-treesitter-textobjects",
		commit = "5ca4aaa",
		branch = "master",
	},
	commit = "42fc28b",
	branch = "master",
	build = ":TSUpdate",
	init = function()
		local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")

		-- This repeats the last query with always previous direction and to the start of the range.
		vim.keymap.set({ "n", "x", "o" }, "<home>", function()
			ts_repeat_move.repeat_last_move({ forward = false, start = true })
		end)

		-- This repeats the last query with always next direction and to the end of the range.
		vim.keymap.set({ "n", "x", "o" }, "<end>", function()
			ts_repeat_move.repeat_last_move({ forward = true, start = false })
		end)
	end,
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
			textobjects = {
				-- `af`, `if`, `ac`, `ic`, etc.
				select = {
					enable = true,
					lookahead = true, -- jump forward automatically

					keymaps = {
						["=="] = "@assignment.outer",
						["=l"] = "@assignment.lhs",
						["=r"] = "@assignment.rhs",

						["in"] = "@number.inner",
						["an"] = "@number.inner",

						["ii"] = "@conditional.inner",
						["ai"] = "@conditional.outer",

						-- ["ig"] = "@parameter.inner",
						-- ["ag"] = "@parameter.outer",

						["ia"] = "@parameter.inner",
						["aa"] = "@parameter.outer",

						["ib"] = "@block.inner",
						["ab"] = "@block.outer",

						["ic"] = "@comment.outer",
						["ac"] = "@comment.outer",

						["am"] = "@function.outer",
						["im"] = "@function.inner",

						["af"] = "@call.outer",
						["if"] = "@call.inner",

						["at"] = "@class.outer",
						["it"] = "@class.inner",

						["al"] = "@loop.outer",
						["il"] = "@loop.inner",

						["ar"] = "@return.outer",
						["ir"] = "@return.inner",
					},
				},

				-- swap parameters with <leader>a / <leader>A
				swap = {
					enable = true,
					swap_next = {
						["<leader>a"] = "@parameter.inner",
					},
					swap_previous = {
						["<leader>A"] = "@parameter.inner",
					},
				},
			},
		})
	end,
}
