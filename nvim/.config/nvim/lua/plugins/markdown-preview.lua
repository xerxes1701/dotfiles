-- render content of a markdown file in a synchronized browser window
-- https://github.com/iamcco/markdown-preview.nvim

return {
	"iamcco/markdown-preview.nvim",
	commit = "a923f5f",
	cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
	-- corepack ships with node, so yarn need not be installed; --frozen-lockfile
	-- installs exactly what the plugin's yarn.lock pins
	build = "cd app && COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack yarn install --frozen-lockfile",
	init = function()
		vim.g.mkdp_filetypes = { "markdown" }
		-- WSL has no Linux browser and xdg-open fails silently: open the
		-- preview in the default Windows browser instead. The server calls
		-- this by name over RPC, so it must be a Vimscript function.
		if vim.fn.has("wsl") == 1 then
			vim.cmd([[
				function! MkdpOpenInWindows(url) abort
					call jobstart(['/mnt/c/Windows/explorer.exe', a:url])
				endfunction
			]])
			vim.g.mkdp_browserfunc = "MkdpOpenInWindows"
		end
	end,
	ft = { "markdown" },
}
