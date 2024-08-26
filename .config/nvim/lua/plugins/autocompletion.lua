-- generic autocompletion based on current buffer, file system paths, and snippets
-- https://github.com/hrsh7th/nvim-cmp

return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		"hrsh7th/cmp-buffer", -- source for text in buffer
		"hrsh7th/cmp-nvim-lsp-signature-help",
		"hrsh7th/cmp-nvim-lua",
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-path", -- source for file system paths
		{
			"L3MON4D3/LuaSnip",
			version = "v2.*",
			build = "make install_jsregexp",
		},
		"saadparwaiz1/cmp_luasnip", -- source for lua snippest
		"rafamadriz/friendly-snippets", -- useful snippets
		"onsails/lspkind.nvim", -- vs-code like pictograms
	},
	config = function()
		local cmp = require("cmp")
		local luasnip = require("luasnip")
		local lspkind = require("lspkind")

		-- load vs-code style snippets from installed plugins (friendly-snippets)
		require("luasnip.loaders.from_vscode").lazy_load()

		cmp.setup({
			formatting = {
				format = function(entry, vim_item)
					vim_item.abbr = string.sub(vim_item.abbr, 1, 40)
					return vim_item
				end,
			},
			snippets = {
				-- configure how nvim interacts with snippets engine
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-k>"] = cmp.mapping.select_prev_item(),
				["<C-j>"] = cmp.mapping.select_next_item(),
				["<C-f>"] = cmp.mapping.scroll_docs(-4),
				["<C-b>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(), -- show suggestions
				["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({
					behavior = cmp.ConfirmBehavior.Insert,
					select = true,
				}),
				["<Tab>"] = cmp.mapping.confirm({
					behavior = cmp.ConfirmBehavior.Insert,
					select = true,
				}),
			}),
			window = {
				completion = cmp.config.window.bordered(),
				documentation = cmp.config.window.bordered(),
			},
			sources = cmp.config.sources({
				{ name = "nvim_lsp" },
				{ name = "nvim_lsp_signature_help" },
				{ name = "nvim_lua" },
				{ name = "luasnip" }, -- snippest
				{ name = "buffer" }, -- text in buffer
				{ name = "path" }, -- file system pahts
			}),
			formatting = {
				format = lspkind.cmp_format({
					maxwith = 50,
					ellipsis_char = "...",
					before = function(_, vim_item)
						local maxwitdh = math.floor(0.45 * vim.o.columns)
						vim_item.abbr = string.sub(vim_item.abbr, 1, maxwitdh)
						return vim_item
					end,
				}),
			},
		})
	end,
}
