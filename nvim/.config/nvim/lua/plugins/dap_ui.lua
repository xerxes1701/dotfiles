-- debugger UI for nvim-dap
-- https://github.com/rcarriga/nvim-dap-ui

return {
	"rcarriga/nvim-dap-ui",
	commit = "cf91d5e",
	dependencies = {
		{ "nvim-neotest/nvim-nio", commit = "21f5324" },
		"mfussenegger/nvim-dap",
	},
	config = function()
		local dap = require("dap")
		local dapui = require("dapui")

		dapui.setup({})

		dap.listeners.before.attach.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.launch.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.event_terminated.dapui_config = function()
			dapui.close()
		end
		dap.listeners.before.event_exited.dapui_config = function()
			dapui.close()
		end

		vim.keymap.set("n", "<F3>q", dap.terminate, { desc = "debug stop" })
		vim.keymap.set("n", "<F3>bd", dap.clear_breakpoints, { desc = "debug clear breakpoints" })
		vim.keymap.set("n", "<F3>b", dap.toggle_breakpoint, { desc = "debug toggle breakpoint" })
		vim.keymap.set("n", "<F3>e", dapui.eval, { desc = "debug eval expression" })
		vim.keymap.set("n", "<F3>uu", dapui.toggle, { desc = "debug eval toggle ui" })
		vim.keymap.set("n", "<F3>uf", dapui.float_element, { desc = "debug eval toggle floating ui" })
		vim.keymap.set("n", "<F3>C", dap.run_to_cursor, { desc = "Run to cursor" })
		vim.keymap.set("n", "<F3>cc", dap.continue, { desc = "debug continue" })
		vim.keymap.set("n", "<F3>r", dap.repl.toggle, { desc = "Toggle DAP REPL" })
		vim.keymap.set("n", "<F3>j", dap.down, { desc = "Go down stack frame" })
		vim.keymap.set("n", "<F3>k", dap.up, { desc = "Go up stack frame" })

		vim.keymap.set("n", "<F5>", dap.continue, { desc = "debug continue" })
		vim.keymap.set("n", "<F6>", dap.step_out, { desc = "debug setp out" })
		vim.keymap.set("n", "<F7>", dap.step_over, { desc = "debug step over" })
		vim.keymap.set("n", "<F8>", dap.run_to_cursor, { desc = "Run to cursor" })
		vim.keymap.set("n", "<F9>", dap.step_into, { desc = "debug step into" })

		vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "", linehl = "", numhl = "" })
		vim.fn.sign_define("DapStopped", { text = "▶️", texthl = "", linehl = "", numhl = "" })
	end,
}
