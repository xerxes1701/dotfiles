-- parsing, ast, syntax highlighting, indentation, ...
-- https://github.com/nvim-treesitter/nvim-treesitter
--
-- NOTE: this plugin is on the `main` branch. The old `master` branch was archived
-- at v0.10.0 and is incompatible with Neovim 0.12: it registers its query
-- directives with `all = false`, an option 0.12 no longer honours, so handlers
-- receive node *lists* instead of nodes and crash with
--   "attempt to call method 'range' (a nil value)"
-- as soon as a query uses one (e.g. `#set-lang-from-info-string!` in its markdown
-- injections, which fires on every fenced code block). `main` drops those
-- directives entirely, but is a full API rewrite -- see the notes inline below.

local ensure_installed = {
	"lua",
	"vim",
	"vimdoc",
	"javascript",
	"html",
	"json",
	"toml",
	"xml",
	"rust",
	"c_sharp",
	"markdown",
	"markdown_inline",
}

return {
	"nvim-treesitter/nvim-treesitter",
	-- `main` has no shared history with `master`, so the old 42fc28b pin cannot
	-- carry over -- and lazy.nvim lets `commit` win over `branch`, which would
	-- have silently kept us on the archived tree.
	branch = "main",
	commit = "8b98b447",
	build = ":TSUpdate",
	dependencies = {
		{ "nvim-treesitter/nvim-treesitter-textobjects", commit = "898ee307df58f854d11cd7edd06472574d48014e", branch = "main" },
	},
	config = function()
		local ts = require("nvim-treesitter")

		-- Defaults are fine; parsers/queries go to `stdpath('data')/site`.
		ts.setup()

		-- `ensure_installed` is gone on `main`. `install` is async and a no-op for
		-- parsers that are already present.
		ts.install(ensure_installed)

		-- The `highlight` and `indent` modules are gone on `main`; both are enabled
		-- per buffer now. This autocmd also replaces `auto_install = true`.
		local available ---@type table<string, true>?

		local function is_available(lang)
			if not available then
				available = {}
				for _, l in ipairs(ts.get_available()) do
					available[l] = true
				end
			end
			return available[lang] == true
		end

		local function attach(buf, lang)
			if not vim.api.nvim_buf_is_valid(buf) then
				return false
			end
			if not pcall(vim.treesitter.start, buf, lang) then
				return false
			end
			-- Only for languages that actually ship an `indents` query, matching what
			-- the old `indent = { enable = true }` module did.
			if vim.treesitter.query.get(lang, "indents") then
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
			return true
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
			callback = function(ev)
				local lang = vim.treesitter.language.get_lang(ev.match) or ev.match
				if attach(ev.buf, lang) then
					return
				end
				if not is_available(lang) then
					return
				end
				ts.install(lang):await(vim.schedule_wrap(function()
					attach(ev.buf, lang)
				end))
			end,
		})

		-- incremental selection: also gone on `main`. Neovim 0.12 ships equivalents
		-- (:h treesitter-incremental-selection) but binds them to `an`/`in`, which
		-- the number textobjects below already claim -- so drive the same functions
		-- from the original <A-v>/<A-V> keys. `vim.treesitter._select` is what the
		-- built-in mappings call; it is private, so this is the one line here that
		-- could break on a Neovim upgrade.
		local tsselect = require("vim.treesitter._select")
		vim.keymap.set("n", "<A-v>", function()
			vim.cmd("normal! v")
			tsselect.select_parent(vim.v.count1)
		end, { silent = true, desc = "Init selection" })
		vim.keymap.set("x", "<A-v>", function()
			tsselect.select_parent(vim.v.count1)
		end, { silent = true, desc = "Increment node selection" })
		vim.keymap.set("x", "<A-V>", function()
			tsselect.select_child(vim.v.count1)
		end, { silent = true, desc = "Decrement node selection" })

		-- nvim-treesitter-textobjects (main branch) is a standalone plugin with its
		-- own setup and manual keymaps instead of the old `nvim-treesitter.configs`
		-- `textobjects` module.
		require("nvim-treesitter-textobjects").setup({
			select = {
				lookahead = true, -- jump forward automatically
			},
			move = {
				set_jumps = true,
			},
		})

		local ts_repeat_move = require("nvim-treesitter-textobjects.repeatable_move")

		-- This repeats the last query with always previous direction and to the start of the range.
		vim.keymap.set({ "n", "x", "o" }, "<home>", function()
			ts_repeat_move.repeat_last_move({ forward = false, start = true })
		end)

		-- This repeats the last query with always next direction and to the end of the range.
		vim.keymap.set({ "n", "x", "o" }, "<end>", function()
			ts_repeat_move.repeat_last_move({ forward = true, start = false })
		end)

		-- `af`, `if`, `ac`, `ic`, etc.
		local select = require("nvim-treesitter-textobjects.select")
		local select_keymaps = {
			["=="] = "@assignment.outer",
			["=l"] = "@assignment.lhs",
			["=r"] = "@assignment.rhs",

			["in"] = "@number.inner",
			["an"] = "@number.inner",

			["ii"] = "@conditional.inner",
			["ai"] = "@conditional.outer",

			["ia"] = "@parameter.inner",
			["aa"] = "@parameter.outer",

			["ib"] = "@block.inner",
			["ab"] = "@block.outer",

			["ic"] = "@comment.outer",
			["ac"] = "@comment.outer",

			["am"] = "@function.outer",
			["im"] = "@function.inner",

			["af"] = "@call.outer",
			["if"] = "@call.inner",

			["at"] = "@class.outer",
			["it"] = "@class.inner",

			["al"] = "@loop.outer",
			["il"] = "@loop.inner",

			["ar"] = "@return.outer",
			["ir"] = "@return.inner",
		}
		for lhs, query_string in pairs(select_keymaps) do
			vim.keymap.set({ "x", "o" }, lhs, function()
				select.select_textobject(query_string, "textobjects")
			end, { silent = true, desc = "Select " .. query_string })
		end

		-- swap parameters with <leader>a / <leader>A
		local swap = require("nvim-treesitter-textobjects.swap")
		vim.keymap.set("n", "<leader>a", function()
			swap.swap_next("@parameter.inner")
		end, { silent = true, desc = "Swap next parameter" })
		vim.keymap.set("n", "<leader>A", function()
			swap.swap_previous("@parameter.inner")
		end, { silent = true, desc = "Swap previous parameter" })
	end,
}
