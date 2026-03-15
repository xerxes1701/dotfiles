-- parsing, ast, syntax highlighting, indentation, ...
-- https://github.com/nvim-treesitter/nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	dependencies = {
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "master",
	},
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
						["af"] = "@function.outer",
						["if"] = "@function.inner",
						["ac"] = "@class.outer",
						["ic"] = "@class.inner",
					},
				},

				-- ]m / [m etc.
				move = {
					enable = true,
					set_jumps = true, -- put jumps in jumplist

					goto_next_start = {
						["]m"] = "@function.outer",
						["]M"] = "@function.inner",
						["]]"] = "@class.outer",
						["]A"] = "@attribute.outer",
						["]a"] = "@attribute.inner",
						["]P"] = "@parameter.outer",
						["]p"] = "@parameter.inner",
					},
					goto_previous_start = {
						["[m"] = "@function.outer",
						["[M"] = "@function.inner",
						["[["] = "@class.outer",
						["[A"] = "@attribute.outer",
						["[a"] = "@attribute.inner",
						["[P"] = "@parameter.outer",
						["[p"] = "@parameter.inner",
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
