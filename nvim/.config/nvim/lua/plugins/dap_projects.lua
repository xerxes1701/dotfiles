return {
	"ldelossa/nvim-dap-projects",
	commit = "f319ffd",
	config = function()
		local dap = require("dap")

		dap.default_configurations = {}
		dap.default_configurations.cs = {
			type = "coreclr",
			name = "launch - netcoredbg",
			request = "launch",
			justMyCode = false,
			stopAtEntry = false,
			program = function()
				return vim.fn.input("path to dll: ", vim.fn.getcwd() .. "/App/bin/Debug/", "file")
			end,
			env = {
				ASPNETCORE_ENVIRONMENT = function()
					return "Development"
				end,
				ASPNETCORE_URLS = function()
					return "http://localhost:5050"
				end,
			},
			cwd = function()
				return vim.fn.getcwd()
			end,
		}

		-- dap.configurations.cs = {
		-- 	dap.default_configurations.cs,
		-- }

		-- this will reset `dap.configurations` and `dap.adapters` to empty tables,
		-- if a `.nvim-dap.lua` file is found in the current working directory
		-- assuming that `dap.configurations` and `dap.adapters` will be set in that file
		-- require("nvim-dap-projects").search_project_config()
		--
		-- local mason_settings = require("mason.settings")
		-- local mason_bin_path = mason_settings.current.install_root_dir
		--
		-- dap.adapters.coreclr = {
		-- 	type = "executable",
		-- 	command = mason_bin_path .. "/packages/netcoredbg/netcoredbg/netcoredbg",
		-- 	args = { "--interpreter=vscode" },
		-- }

		-- print(vim.inspect(dap.adapters.coreclr.command))
	end,
}
