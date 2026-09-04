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

local function open(path, filetype, want_lsp)
	if not pcall(vim.cmd, "edit " .. vim.fn.fnameescape(path)) then
		table.insert(errs, "cannot open " .. path)
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
	local ok, parser = pcall(vim.treesitter.get_parser, 0, lang)
	if not (ok and parser and pcall(function()
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
