-- Health check run inside the sandbox profile by verify.sh.
-- Writes a CHECK line to stderr and exits non-zero on any finding.
--
-- Two traps this file exists to avoid, both of which once let a broken
-- config pass as healthy:
--
--   1. lazy.nvim catches errors thrown by a plugin's `config` and reports
--      them through vim.notify. A pcall around lazy.load() sees success.
--      So we intercept vim.notify instead.
--   2. Some plugins defer their complaint. lualine waits 2s after VimEnter
--      before warning that its theme was not found. Quitting earlier misses
--      it, so we wait the warning out before summarizing.

local errs = {}

local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
	if level == vim.log.levels.ERROR or level == vim.log.levels.WARN then
		local first_line = tostring(msg):gsub("\n.*", "")
		table.insert(errs, ("notify[%s] %s"):format(tostring(level), first_line))
	end
	return orig_notify(msg, level, opts)
end

local lazy = require("lazy")

-- Force every plugin through its `config`. Lazy-loaded specs would
-- otherwise never run here, which is how a broken bufferline config
-- survived a full check.
for _, plugin in ipairs(lazy.plugins()) do
	local ok, err = pcall(function()
		lazy.load({ plugins = { plugin.name }, wait = true })
	end)
	if not ok then
		table.insert(errs, ("load %s: %s"):format(plugin.name, tostring(err)))
	end
end

-- nvim-treesitter `main` builds every parser itself, with the tree-sitter CLI
-- (0.26.1 or later) and a C compiler; there are no prebuilt downloads. Without
-- the CLI every install fails, no parser ever exists, and a plugin that calls
-- vim.treesitter.start without a pcall -- markview.nvim does, on BufEnter --
-- turns `:edit file.typ` into an error. Name that cause as its own finding so
-- the report does not stop at the symptom. The archived `master` branch
-- compiled with `cc` alone, which is why this prerequisite is new.
local have_ts_cli = vim.fn.executable("tree-sitter") == 1
if not have_ts_cli then
	table.insert(errs, "tree-sitter CLI not on PATH: nvim-treesitter (main) cannot build parsers; install tree-sitter-cli 0.26.1+ (cargo install --locked tree-sitter-cli)")
end
if vim.fn.executable("cc") ~= 1 then
	table.insert(errs, "no C compiler (cc) on PATH: nvim-treesitter cannot build parsers")
end

-- The treesitter spec starts `ts.install(ensure_installed)` when it loads and
-- returns at once. A probe opened before its parser has landed fails on that
-- race, not on the config, so wait for the parsers the probes need first.
-- Pointless without the CLI: nothing would ever arrive.
local function wait_for_parsers(langs)
	if not have_ts_cli then
		return
	end
	vim.wait(300000, function()
		for _, lang in ipairs(langs) do
			if not vim.treesitter.language.add(lang) then
				return false
			end
		end
		return true
	end, 500)
end
wait_for_parsers({ "rust", "c_sharp", "typst", "lua" })

local function open(path, filetype, want_lsp)
	local opened, open_err = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(path))
	if not opened then
		-- Carry the message: an autocmd of some plugin failing on this filetype
		-- lands here too, and "cannot open" alone does not say which one.
		table.insert(errs, ("cannot open %s: %s"):format(path, tostring(open_err):gsub("\n.*", "")))
		return
	end

	vim.wait(10000, function()
		return #vim.lsp.get_clients({ bufnr = 0 }) > 0
	end, 100)

	local names = {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
		table.insert(names, client.name)
	end

	if vim.bo.filetype ~= filetype then
		table.insert(errs, ("%s: filetype is %q, expected %q"):format(path, vim.bo.filetype, filetype))
	end

	-- The parser is named after the language, which is not always the filetype:
	-- C# is filetype `cs` and language `c_sharp`. Resolve it the same way the
	-- FileType autocmd in the treesitter spec does.
	local lang = vim.treesitter.language.get_lang(filetype) or filetype

	-- nvim-treesitter `main` installs parsers asynchronously, so the first run
	-- after a language joins `ensure_installed` reaches this line before the
	-- parser is on disk. Waiting turns that into a slow pass instead of a
	-- spurious finding; a language that never installs still fails.
	-- Skip the wait when no parser can ever arrive; it only slows the
	-- finding down.
	local parser
	vim.wait(have_ts_cli and 120000 or 0, function()
		local got, p = pcall(vim.treesitter.get_parser, 0, lang)
		parser = got and p or nil
		return parser ~= nil
	end, 200)

	if not (parser and pcall(function()
		parser:parse()
	end)) then
		table.insert(errs, ("%s: no %s treesitter parse"):format(path, lang))
	end

	-- rustaceanvim names its client "rust-analyzer"; mason-started servers
	-- use "rust_analyzer". Accept either spelling.
	if want_lsp then
		local attached = false
		for _, name in ipairs(names) do
			if name:gsub("[-_]", "") == want_lsp:gsub("[-_]", "") then
				attached = true
			end
		end
		if not attached then
			table.insert(errs, ("%s: %s did not attach"):format(path, want_lsp))
		end
	end

	io.stderr:write(("  %-18s ft=%-5s lsp=%s\n"):format(
		vim.fn.fnamemodify(path, ":t"),
		vim.bo.filetype,
		#names > 0 and table.concat(names, ",") or "none"
	))
end

local config = vim.fn.stdpath("config")

-- Rust: the fixture crate. rust-analyzer is required only when it is
-- installed, so the check still runs on a machine without a Rust toolchain.
local rust_lsp = vim.fn.executable("rust-analyzer") == 1 and "rust_analyzer" or nil
open(config .. "/verify/fixture/src/main.rs", "rust", rust_lsp)

-- C#: the fixture project. roslyn.nvim names its client "roslyn", not
-- "roslyn_ls" as nvim-lspconfig does, and the name comparison in `open` only
-- folds - and _, so the spelling here has to be the plugin's. Required only
-- when the server is on PATH; it comes from mason, which the sandbox does not
-- install, so normally this probe checks the filetype and the parser.
local cs_lsp = vim.fn.executable("roslyn-language-server") == 1 and "roslyn" or nil
open(config .. "/verify/fixture-cs/Program.cs", "cs", cs_lsp)

-- Typst: the fixture project. Its `typst.toml` is the root marker both
-- tinymist and typst-preview.nvim look for, and main.typ imports chapter.typ,
-- so an attached client has a cross-file reference to resolve. tinymist comes
-- from mason, which the sandbox does not install, so it is required only when
-- some other install already put it on PATH.
local typst_lsp = vim.fn.executable("tinymist") == 1 and "tinymist" or nil
open(config .. "/verify/fixture-typst/main.typ", "typst", typst_lsp)

-- Typst again, the way a file is first met in practice: empty, just created,
-- in a directory with no typst.toml. That is the case that surfaced the
-- missing parser on 2026-09-09; the fixture project alone would have found it
-- too, but a root marker and existing content are two variables this probe
-- removes. tinymist attaches regardless (it falls back to the file's
-- directory), so the client requirement is the same.
local loose_dir = vim.fn.tempname()
vim.fn.mkdir(loose_dir, "p")
local loose_typ = loose_dir .. "/0001-erste-seite.typ"
vim.fn.writefile({}, loose_typ)
open(loose_typ, "typst", typst_lsp)

-- Lua: this config's own files. Servers here come from mason, which the
-- sandbox does not install, so no client is required.
open(config .. "/init.lua", "lua", nil)
open(config .. "/lua/plugins/bufferline.lua", "lua", nil)

-- Give bufferline something to draw; its spec sets mode = "tabs".
vim.cmd("tabnew | tabnext")

-- Trap 2 above: outlast lualine's 2s deferred warning.
vim.wait(3500, function()
	return false
end)

local loaded = #vim.tbl_filter(function(p)
	return p._.loaded
end, lazy.plugins())

io.stderr:write(("CHECK loaded=%d/%d errors=%d\n"):format(loaded, #lazy.plugins(), #errs))
for _, err in ipairs(errs) do
	io.stderr:write("  ERR " .. err .. "\n")
end

vim.cmd(#errs == 0 and "qa!" or "cquit!")
