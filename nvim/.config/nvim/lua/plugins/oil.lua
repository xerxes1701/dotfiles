-- manage/edit filesystem-directory like a regular vim buffer
-- https://github.com/stevearc/oil.nvim

return {
	"stevearc/oil.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	commit = "0fcc838",
	config = function()
		local oil = require("oil")
		oil.setup({
			-- Colored, modern icons. The "icon" column pulls glyphs + highlight
			-- groups from nvim-web-devicons (a dependency above), so icons are
			-- colored out of the box. Requires a Nerd Font in your terminal.
			columns = { "icon" },
			-- Reserve three sign slots: two for oil-git-status.nvim (index +
			-- working-tree git status) and one for the hand-rolled unsaved-buffer
			-- marker in oil_status.lua.
			--
			-- Blank the global custom 'statuscolumn' (see lua/statuscolumn.lua) for
			-- oil windows: that statuscolumn only renders a single diagnostic/git
			-- sign per line and would otherwise hide the oil status signs. An empty
			-- value falls back to Neovim's native gutter, which draws all signs.
			win_options = {
				signcolumn = "yes:3",
				statuscolumn = "",
			},
			-- Async, syntax-highlighted file preview.
			preview_win = {
				-- Refresh the preview as you move the cursor over entries.
				update_on_cursor_moved = true,
				-- "fast_scratch" renders into a scratch buffer with syntax
				-- highlighting applied asynchronously (no side effects / LSP).
				-- Use "load" instead for full Treesitter + LSP at some perf cost.
				preview_method = "fast_scratch",
				disable_preview = function(filename)
					return false
				end,
				win_options = {},
			},
			keymaps = {
				["g?"] = "actions.show_help",
				["<CR>"] = "actions.select",
				["gv"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
				["gh"] = {
					"actions.select",
					opts = { horizontal = true },
					desc = "Open the entry in a horizontal split",
				},
				["gt"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
				["gp"] = "actions.preview",
				["gq"] = "actions.close",
				["gr"] = "actions.refresh",
				["-"] = "actions.parent",
				["_"] = "actions.open_cwd",
				["`"] = "actions.cd",
				["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
				["gs"] = "actions.change_sort",
				["gx"] = "actions.open_external",
				["g."] = "actions.toggle_hidden",
				["g\\"] = "actions.toggle_trash",
			},
		})

		local keymap = vim.api.nvim_set_keymap
		keymap("n", "<leader>ed", "<cmd>edit %:p:h<CR>", { desc = "edit current file's directory" })
		keymap("n", "<leader>eD", "<cmd>edit .<CR>", { desc = "edit current directory" })

		-- Unsaved-buffer indicator (git status is handled by oil-git-status.nvim).
		-- Pure-Lua, uses only oil's public API + events (no source changes).
		require("oil_status").setup()

		-- Auto-open the preview split when entering an oil buffer. Combined with
		-- preview_win.update_on_cursor_moved above, this gives a live, always-on
		-- file preview. Oil already preselects (places the cursor on) the file
		-- you came from automatically, so the preview starts on that file.
		vim.api.nvim_create_autocmd("User", {
			pattern = "OilEnter",
			callback = vim.schedule_wrap(function(args)
				if vim.api.nvim_get_current_buf() == args.data.buf and oil.get_cursor_entry() then
					oil.open_preview()
				end
			end),
		})
	end,
}
