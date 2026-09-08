-- live browser preview of a typst document, rendered by tinymist
-- https://github.com/chomosuke/typst-preview.nvim

return {
	"chomosuke/typst-preview.nvim",
	commit = "1c2e19486397be1c580b560fc50ee36abe329c46",
	ft = "typst",
	cmd = {
		"TypstPreview",
		"TypstPreviewStop",
		"TypstPreviewToggle",
		"TypstPreviewUpdate",
		"TypstPreviewFollowCursor",
		"TypstPreviewNoFollowCursor",
		"TypstPreviewFollowCursorToggle",
		"TypstPreviewSyncCursor",
	},
	keys = {
		{ "<leader>Tp", "<cmd>TypstPreviewToggle<CR>", desc = "toggle typst preview" },
		{ "<leader>Tf", "<cmd>TypstPreviewFollowCursorToggle<CR>", desc = "toggle preview follow cursor" },
		{ "<leader>Ts", "<cmd>TypstPreviewSyncCursor<CR>", desc = "scroll preview to cursor" },
	},
	-- A function, not a table: `vim.fn.exepath` has to run when the plugin loads,
	-- not while lazy.nvim is still reading the specs. mason prepends its bin
	-- directory to PATH in its own setup, which happens later than spec parsing.
	opts = function()
		-- `setup()` downloads its own tinymist and websocat into
		-- stdpath("data")/typst-preview/. mason already installs a tinymist for the
		-- LSP client (see mason.lua), so hand that one over: preview and language
		-- server then run the same binary, and no second tinymist release -- one
		-- this repository never pinned or reviewed -- is fetched behind our back.
		-- Stays nil until mason has installed it, so the plugin can still
		-- bootstrap itself on a fresh profile.
		local tinymist = vim.fn.exepath("tinymist")

		return {
			dependencies_bin = {
				tinymist = tinymist ~= "" and tinymist or nil,
			},
		}
	end,
}
