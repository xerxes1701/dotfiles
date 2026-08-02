-- Browser-like back/forward navigation through buffer history (per window)
-- https://github.com/ckarnell/history-traverse
--
-- This is a vimscript plugin configured via `g:` globals. Those must be set
-- BEFORE the plugin loads, so they go in `init` (which lazy.nvim runs before
-- the plugin is sourced) rather than `config`/`opts`.

return {
	"ckarnell/history-traverse",
	-- The plugin defines its commands on load, so load it on buffer read so
	-- the commands are always available when navigating.
	event = "BufReadPost",
	init = function()
		-- Filetypes to skip when recording history (default: { "netrw" })
		vim.g.history_ft_ignore = { "netrw", "oil" }

		-- File names to skip when recording history (default: {})
		-- vim.g.history_fn_ignore = { "hate_this_file.py" }

		-- Max length of each buffer's history (default: 100)
		vim.g.history_max_len = 1000

		-- Statusline indicator characters (optional; these are the defaults)
		-- vim.g.history_indicator_back_active = "⬅"
		-- vim.g.history_indicator_back_inactive = "⇦"
		-- vim.g.history_indicator_forward_active = "➡"
		-- vim.g.history_indicator_forward_inactive = "⇨"
		-- vim.g.history_indicator_separator = ""
	end,
	keys = {
		{ "gj", "<cmd>HisTravBack<cr>", desc = "History: go back" },
		{ "gk", "<cmd>HisTravForward<cr>", desc = "History: go forward" },
	},
}
