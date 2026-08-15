-- LSP Server configurations
-- https://github.com/neovim/nvim-lspconfig

return {
	"neovim/nvim-lspconfig",
	commit = "dc2f86d",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		{ "antosha417/nvim-lsp-file-operations", config = true, commit = "b9c795d" },
		"saghen/blink.cmp",
	},
	config = function()
		local lspconfig = require("lspconfig")
		local mason_lspconfig = require("mason-lspconfig")

		-- define keybinding that will be avaiable if a LSP Server is attached to the current buffer
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				local client = vim.lsp.get_client_by_id(ev.data.client_id)

				-- Show inlay hints for any server that provides them.
				if client and client:supports_method("textDocument/inlayHint") then
					vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
				end

				-- Render and keep CodeLenses up to date for servers that provide them.
				if client and client:supports_method("textDocument/codeLens") then
					if vim.g.codelens_enabled == nil then
						vim.g.codelens_enabled = true
					end
					if vim.g.codelens_enabled then
						vim.lsp.codelens.enable(true, { bufnr = ev.buf })
					end
				end

				local keymap = function(mode, key, cmd, opt)
					vim.keymap.set(mode, key, cmd, { desc = opt.desc, buffer = ev.buf, silent = true })
				end

				keymap("n", "gR", "<cmd>Telescope lsp_references<CR>", { desc = "fuzzy find LSP references" })

				keymap("n", "gD", vim.lsp.buf.declaration, { desc = "go to LSP definition" })

				keymap("n", "gd", "<cmd>Telescope lsp_definitions<CR>", { desc = "fuzzy find LSP definitions" })

				keymap("n", "gi", "<cmd>Telescope lsp_implementations<CR>", { desc = "fuzzy find LSP implementations" })

				keymap(
					"n",
					"gt",
					"<cmd>Telescope lsp_type_implementations<CR>",
					{ desc = "fuzzy find LSP type definitions" }
				)

				keymap("n", "<leader>rr", vim.lsp.buf.rename, { desc = "refactor rename" })

				keymap("n", "K", vim.lsp.buf.hover, { desc = "show lsp documentation" })

				keymap("n", "<leader>rSS", "<cmd>LspRestart<CR>", { desc = "restart LSP" })

				keymap("n", "<leader>cl", vim.lsp.codelens.run, { desc = "run CodeLens action" })

				keymap("n", "<leader>cL", function()
					vim.g.codelens_enabled = not vim.g.codelens_enabled
					if vim.g.codelens_enabled then
						vim.lsp.codelens.enable(true, { bufnr = ev.buf })
					else
						vim.lsp.codelens.enable(false, { bufnr = ev.buf })
					end
				end, { desc = "toggle CodeLenses" })

				keymap("n", "<leader>ih", function()
					vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
				end, { desc = "toggle inlay hints" })
			end,
		})
	end,
}
