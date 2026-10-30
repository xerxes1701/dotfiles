-- code formatter
-- https://github.com/stevearc/conform.nvim

return {
	"stevearc/conform.nvim",
	commit = "3543d000dafbc41cc7761d860cfdb24e82154f75",
	event = { "BufReadPre", "BufNewFile" },
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
				-- fsautocomplete formats too, but only through a Fantomas it finds as a
				-- dotnet tool; calling mason's directly does not depend on that lookup.
				fsharp = { "fantomas" },
			},
			-- XAML has no formatter here, so `lsp_fallback` would hand every save to
			-- lemminx, which rewrites the whole file -- what defaults.lua gave XAML a
			-- filetype of its own to avoid. <leader>cf still reaches lemminx.
			format_on_save = function(bufnr)
				if vim.bo[bufnr].filetype == "xaml" then
					return nil
				end
				return { lsp_fallback = true, async = false, timeout_ms = 1000 }
			end,
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
