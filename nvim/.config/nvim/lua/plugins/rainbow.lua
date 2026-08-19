-- rainbow brackets
-- https://github.com/HiPhish/rainbow-delimiters.nvim

return {
	"hiphish/rainbow-delimiters.nvim",
	commit = "012f1480cd9a5fc99fce7678e0a536421a53fc46",
	config = function()
		require("rainbow-delimiters.setup").setup({})
	end,
}
