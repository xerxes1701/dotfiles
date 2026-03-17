return {
	"ray-x/lsp_signature.nvim",
	commit = "af7e407",
	event = "InsertEnter",
	opts = {
		bind = true,
		toggle_key = "<C-d>",
		select_signature_key = "<CS-d>",
		handler_opts = {
			border = "rounded",
		},
	},
	-- or use config
	config = function(_, opts)
		require("lsp_signature").setup(opts)
	end,
}
