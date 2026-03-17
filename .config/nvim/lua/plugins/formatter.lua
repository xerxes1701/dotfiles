-- code formatter
-- https://github.com/stevearc/conform.nvim

return {
	"stevearc/conform.nvim",
	commit = "acc7337",
	event = { "BufReadPre", "BufNewFile" },
	-- newest version requires neovim 0.10
	tag = "v7.0.0",
	config = function()
		local conform = require("conform")

		conform.setup({
			formatters_by_ft = {
				javascript = { "prettier" },
				typescript = { "prettier" },
				javascriptreact = { "prettier" },
				typescriptreact = { "prettier" },
				svelte = { "prettier" },
				css = { "prettier" },
				html = { "prettier" },
				xml = { "prettier" },
				json = { "prettier" },
				yaml = { "prettier" },
				markdown = { "prettier" },
				graphql = { "prettier" },
				lua = { "stylua" },
			},
			format_on_save = {
				lsp_fallback = true,
				async = false,
				timeout_ms = 1000,
			},
		})

		vim.keymap.set({ "n", "v" }, "<leader>cf", function()
			conform.format({
				lsp_fallback = true,
				async = false,
				timeout = 1000,
			})
		end, { desc = "format file or range" })
	end,
}
