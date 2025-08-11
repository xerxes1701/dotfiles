-- autocompete () {} [] `` '' ""
-- https://github.com/windwp/nvim-autopairs

return {
	"windwp/nvim-autopairs",
	event = { "InsertEnter" },
	dependencies = {
		"hrsh7th/nvim-cmp",
	},
	config = function()
		local autopairs = require("nvim-autopairs")
		local cmp = require("cmp")
		local cmp_autopairs = require("nvim-autopairs.completion.cmp")

		autopairs.setup({
			check_ts = true, -- enable treesitter,
			ts_config = {
				lua = { "string" }, -- don't add pairs in lua string
				javascript = { "template_string" }, -- don't add pairs in javascript template_strings
			},
		})

		-- make autopairs and completion work together
		cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
	end,
}
