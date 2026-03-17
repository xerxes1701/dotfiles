-- render content of a markdown file in a synchronized browser window
-- https://github.com/iamcco/markdown-preview.nvim

return {
	"iamcco/markdown-preview.nvim",
	commit = "a923f5f",
	cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
	build = "cd app && yarn install",
	init = function()
		vim.g.mkdp_filetypes = { "markdown" }
	end,
	ft = { "markdown" },
}
