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

		local opts = {
			dependencies_bin = {
				tinymist = tinymist ~= "" and tinymist or nil,
			},
		}

		-- On WSL the plugin hands the preview URL to a bare `explorer.exe`. That
		-- name only resolves when the Windows PATH is appended to $PATH, and
		-- /etc/wsl.conf here sets `appendWindowsPath = false`, so the spawn dies
		-- with ENOENT and no preview ever opens. Interop itself is fine -- the
		-- binary only has to be named in full. There is no Linux browser in this
		-- WSL image either (`www-browser` is lynx), so handing the URL to Windows
		-- is the right call, not a workaround.
		--
		-- `open_cmd` is a format string: `%s` is the URL, and a string command
		-- goes through the shell, hence the quotes. explorer.exe exits 1 even on
		-- success, which is harmless -- the plugin reports stderr, not the exit
		-- code, and explorer writes nothing there.
		if vim.fn.has("wsl") == 1 then
			local explorer = "/mnt/c/Windows/explorer.exe"
			if vim.fn.executable(explorer) == 1 then
				opts.open_cmd = explorer .. ' "%s"'
			end
		end

		return opts
	end,
}
