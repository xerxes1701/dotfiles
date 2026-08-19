return {
	"zbirenbaum/copilot.lua",
	commit = "0a3e091",
	requires = {
		"copilotlsp-nvim/copilot-lsp", -- (optional) for NES functionality
	},
	cmd = "Copilot",
	event = "InsertEnter",
	config = function()
		require("copilot").setup({})
	end,
}
