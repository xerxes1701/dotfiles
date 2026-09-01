return {
	"olimorris/codecompanion.nvim",
	commit = "2b959b2bf5fdb13e3b333c078ba549996e477b7c",
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
