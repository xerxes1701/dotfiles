-- LSP Server configurations
-- https://github.com/neovim/nvim-lspconfig

return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
		{ "folke/neodev.nvim", opts = {} },
	},
	config = function()
		local lspconfig = require("lspconfig")
		local cmp_nvim_lsp = require("cmp_nvim_lsp")
		local mason_lspconfig = require("mason-lspconfig")

		-- define keybinding that will be avaiable if a LSP Server is attached to the current buffer
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
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

				keymap("n", "gnd", vim.diagnostic.goto_next, { desc = "go to next diagnostic" })

				keymap("n", "gpd", vim.diagnostic.goto_prev, { desc = "go to prev diagnostic" })

				keymap({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "show avaiable code action" })

				keymap("n", "<leader>rr", vim.lsp.buf.rename, { desc = "refactor rename" })

				keymap("n", "K", vim.lsp.buf.hover, { desc = "show lsp documentation" })

				keymap("n", "<leader>rSS", "<cmd>LspRestart<CR>", { desc = "restart LSP" })
			end,
		})

		local capabilities = cmp_nvim_lsp.default_capabilities()

		mason_lspconfig.setup_handlers({
			function(server_name)
				lspconfig[server_name].setup({
					capabilities = capabilities,
				})
			end,
			["lua_ls"] = function()
				lspconfig["lua_ls"].setup({
					capabilities = capabilities,
					settings = {
						Lua = {
							diagnostics = {
								globals = { "vim" },
							},
							completion = {
								callSnippet = "Replace",
							},
						},
					},
				})
			end,
		})
	end,
}
