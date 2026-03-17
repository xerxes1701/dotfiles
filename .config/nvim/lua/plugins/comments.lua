-- insert / remove comments via <gc> + motion. (i.e. gcc: toggle for current line, gcG: toggle until end of line, ...)
-- https://github.com/numToStr/Comment.nvim

return {
	"numToStr/Comment.nvim",
	commit = "e30b7f2",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		-- for .tsx, .jsx, .html files
		"JoosepAlviste/nvim-ts-context-commentstring",
		commit = "1b212c2",
	},
	config = function()
		local comment = require("Comment")
		local ts_context_commentstring = require("ts_context_commentstring.integrations.comment_nvim")

		comment.setup({
			pre_hook = ts_context_commentstring.create_pre_hook(),
		})
	end,
}
