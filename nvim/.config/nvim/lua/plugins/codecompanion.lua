return {
	"olimorris/codecompanion.nvim",
	commit = "78203cc",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {
		mcp = {
			servers = {
				["SampleMcpServer"] = {
					cmd = { "dotnet", "run", "--project", "/home/xerxes/code/dn/SampleMcpServer" },
				},
			},
			opts = {
				default_servers = { "SampleMcpServer" },
			},
		},
		opts = {
			-- log_level = "DEBUG", -- or "TRACE"
		},
	},
}
