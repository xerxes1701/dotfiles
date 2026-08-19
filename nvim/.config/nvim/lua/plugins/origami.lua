-- code folding
--

return {
	"chrisgrieser/nvim-origami",
	commit = "e5b527f",
	event = "VeryLazy",
	opts = {}, -- needed even when using default config

	-- recommended: disable vim's auto-folding
	init = function()
		vim.opt.foldlevel = 99
		vim.opt.foldlevelstart = 99
	end,
}
