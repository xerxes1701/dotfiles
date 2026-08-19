-- DAP (Debug Adapter Protocol)
-- https://github.com/mfussenegger/nvim-dap

return {
	"mfussenegger/nvim-dap",
	commit = "a9d8cb6",
	dependencies = {
		"GustavEikaas/easy-dotnet.nvim",
	},
	config = function()
		local dap = require("dap")
		local dotnet = require("easy-dotnet")

		-- special variables viewer specific for .NET
		require("easy-dotnet.netcoredbg").register_dap_variables_viewer()

		local debug_dll = nil
		local function ensure_dll()
			if debug_dll ~= nil then
				return debug_dll
			end
			local dll = dotnet.get_debug_dll(true)
			debug_dll = dll
			return dll
		end
		-- Reset debug_dll after each terminated session
		dap.listeners.before["event_terminated"]["easy-dotnet"] = function()
			debug_dll = nil
		end

		local mason_settings = require("mason.settings")
		local mason_bin_path = mason_settings.current.install_root_dir
		dap.adapters.coreclr = {
			type = "executable",
			command = mason_bin_path .. "/packages/netcoredbg/netcoredbg/netcoredbg",
			args = { "--interpreter=vscode" },
		}

		local function rebuild_project(co, path)
			local spinner = require("easy-dotnet.ui-modules.spinner").new()
			spinner:start_spinner("Building")
			vim.fn.jobstart(string.format("dotnet build %s", path), {
				on_exit = function(_, return_code)
					if return_code == 0 then
						spinner:stop_spinner("Built successfully")
					else
						spinner:stop_spinner("Build failed with exit code " .. return_code, vim.log.levels.ERROR)
						error("Build failed")
					end
					coroutine.resume(co)
				end,
			})
			coroutine.yield()
		end

		for _, value in ipairs({ "cs", "fsharp" }) do
			dap.configurations[value] = {
				{
					type = "coreclr",
					name = "Program",
					request = "launch",
					env = function()
						local dll = ensure_dll()
						local vars = dotnet.get_environment_variables(dll.project_name, dll.relative_project_path)
						return vars or nil
					end,
					program = function()
						local dll = ensure_dll()
						local co = coroutine.running()
						rebuild_project(co, dll.project_path)
						vim.notify(dll.relative_dll_path)
						return dll.relative_dll_path
					end,
					cwd = function()
						local dll = ensure_dll()
						return dll.relative_project_path
					end,
				},
			}
		end
	end,
}
