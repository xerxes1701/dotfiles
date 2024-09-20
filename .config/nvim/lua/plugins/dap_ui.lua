-- debugger UI for nvim-dap
-- https://github.com/rcarriga/nvim-dap-ui

return {
	"rcarriga/nvim-dap-ui",
	dependencies = {
		"nvim-neotest/nvim-nio",
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

		vim.keymap.set("n", "<leader>ce", dapui.eval, { desc = "debug eval expression" })
		vim.keymap.set("n", "<leader>cdu", dapui.toggle, { desc = "debug eval toggle ui" })
		vim.keymap.set("n", "<leader>cdf", dapui.float_element, { desc = "debug eval toggle floating ui" })
		vim.keymap.set("n", "<F5>", dap.continue, { desc = "debug continue" })
		vim.keymap.set("n", "<F10>", dap.step_over, { desc = "debug step over" })
		vim.keymap.set("n", "<F11>", dap.step_into, { desc = "debug step into" })
		vim.keymap.set("n", "<F12>", dap.step_out, { desc = "debug setp out" })
		vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "debug toggle breakpoint" })

		vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "", linehl = "", numhl = "" })
		vim.fn.sign_define("DapStopped", { text = "▶️", texthl = "", linehl = "", numhl = "" })
	end,
}
