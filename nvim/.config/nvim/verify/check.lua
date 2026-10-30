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
wait_for_parsers({ "rust", "c_sharp", "fsharp", "xml", "typst", "lua", "markdown" })

-- rustaceanvim names its client "rust-analyzer"; mason-started servers
-- use "rust_analyzer". Accept either spelling.
local function same_lsp(a, b)
	return a:gsub("[-_]", "") == b:gsub("[-_]", "")
end

local function open(path, filetype, want_lsp)
	local opened, open_err = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(path))
	if not opened then
		-- Carry the message: an autocmd of some plugin failing on this filetype
		-- lands here too, and "cannot open" alone does not say which one.
		table.insert(errs, ("cannot open %s: %s"):format(path, tostring(open_err):gsub("\n.*", "")))
		return
	end

	-- Wait for the wanted client, not for any client: a buffer can get more
	-- than one, and they do not arrive together. easy-dotnet's in-process
	-- client attaches to a C# buffer at once, roslyn a moment later, so a wait
	-- for the first client read the names before roslyn was there.
	vim.wait(10000, function()
		for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
			if not want_lsp or same_lsp(client.name, want_lsp) then
				return true
			end
		end
		return false
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

	if want_lsp then
		local attached = false
		for _, name in ipairs(names) do
			if same_lsp(name, want_lsp) then
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

-- F#: the fixture project, so fsautocomplete has a `.fsproj` to load. `.fs`
-- is also Forth, and Neovim picks between the two by content, so the filetype
-- half of `open` matters here. Beyond attaching, F# support is checked the way
-- it is used: the buffer must be highlighted, not just parsed, hover must answer
-- with a type (that needs the project loaded and type-checked, which a bare
-- attach does not), and conform must format through Fantomas. The server and
-- the formatter come from mason, which the sandbox does not install, so each
-- half is required only when its tool is on PATH.
local function check_fsharp()
	local fs_lsp = vim.fn.executable("fsautocomplete") == 1 and "fsautocomplete" or nil
	open(config .. "/verify/fixture-fs/Program.fs", "fsharp", fs_lsp)
	if vim.bo.filetype ~= "fsharp" then
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	local results = {}

	if have_ts_cli then
		results.highlight = vim.treesitter.highlighter.active[buf] and "on" or "off"
		if results.highlight == "off" then
			table.insert(errs, "Program.fs: treesitter highlighting did not start")
		end
	end

	local row
	for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		if line:find("^let greet") then
			row = i - 1
		end
	end
	local client = fs_lsp and vim.lsp.get_clients({ bufnr = buf, name = fs_lsp })[1]
	if client and row then
		-- fsautocomplete answers hover with nothing until the project has loaded,
		-- so ask again until the type arrives. The first load runs a design-time
		-- build of the fixture, which takes a while on a cold machine. A plain
		-- loop, not vim.wait: request_sync waits itself, and a wait nested in a
		-- wait's condition re-enters it and floods the server with requests.
		-- The reply is a list of MarkedStrings with the signature broken over
		-- lines, so flatten it and fold whitespace before matching.
		local params = { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = row, character = 5 } }
		local want_sig = "who: string -> string"
		local text = ""
		local deadline = vim.uv.now() + 120000
		while vim.uv.now() < deadline do
			local res = client:request_sync("textDocument/hover", params, 5000, buf)
			local contents = res and res.result and res.result.contents
			local parts = {}
			for _, part in ipairs(vim.islist(contents) and contents or { contents }) do
				table.insert(parts, type(part) == "table" and part.value or part)
			end
			text = table.concat(parts, " "):gsub("%s+", " ")
			if text:find(want_sig, 1, true) then
				break
			end
			vim.wait(1000)
		end
		results.hover = text:find(want_sig, 1, true) and "ok" or "none"
		if results.hover ~= "ok" then
			table.insert(errs, ("Program.fs: hover on greet gave %q, expected its type"):format(text:sub(1, 80)))
		end
	end

	-- Mangle the definition in the buffer, let conform put it back, and throw
	-- the edit away: nothing is written, so format-on-save does not fire and
	-- the committed fixture stays as it is.
	if vim.fn.executable("fantomas") == 1 and row then
		local want = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
		vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { [[let   greet(who:string) =  $"hello, {who}"]] })
		local ok, err = pcall(require("conform").format, { bufnr = buf, async = false, timeout_ms = 10000 })
		local got = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
		results.format = ok and got == want and "ok" or "failed"
		if not ok then
			table.insert(errs, ("Program.fs: formatting threw: %s"):format(tostring(err):gsub("\n.*", "")))
		elseif got ~= want then
			table.insert(errs, ("Program.fs: formatting gave %q, expected %q"):format(got, want))
		end
		vim.cmd("edit!")
	end

	io.stderr:write(("  %-18s highlight=%s hover=%s format=%s\n"):format(
		"Program.fs",
		results.highlight or "-",
		results.hover or "-",
		results.format or "-"
	))
end
check_fsharp()

-- XAML: its own filetype (defaults.lua), highlighted by the xml parser. With
-- lemminx on PATH -- it comes from mason, which the sandbox does not install --
-- the server must attach and report a broken tag as an error. And a save must
-- leave the file as typed: XAML has no conform formatter, and lsp_fallback
-- would otherwise let lemminx rewrite it whole. That half runs on a copy in a
-- temporary directory, since it writes; it holds without lemminx too, but only
-- proves anything with it. Avalonia's .axaml is mapped to the same filetype
-- and runs the same probe.
local function check_xaml(name)
	local xaml_lsp = vim.fn.executable("lemminx") == 1 and "lemminx" or nil
	local fixture = config .. "/verify/fixture-xaml/" .. name
	open(fixture, "xaml", xaml_lsp)
	if vim.bo.filetype ~= "xaml" then
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	local results = {}

	if have_ts_cli then
		results.highlight = vim.treesitter.highlighter.active[buf] and "on" or "off"
		if results.highlight == "off" then
			table.insert(errs, name .. ": treesitter highlighting did not start")
		end
	end

	local client = xaml_lsp and vim.lsp.get_clients({ bufnr = buf, name = xaml_lsp })[1]
	if client then
		-- An end tag that closes the wrong element. Thrown away afterwards with
		-- `edit!`; nothing is written.
		local last = vim.api.nvim_buf_line_count(buf)
		vim.api.nvim_buf_set_lines(buf, last - 1, last, false, { "</Grid>" })
		local ns = vim.lsp.diagnostic.get_namespace(client.id)
		local found = vim.wait(30000, function()
			return #vim.diagnostic.get(buf, { namespace = ns, severity = vim.diagnostic.severity.ERROR }) > 0
		end, 200)
		results.diagnostic = found and "ok" or "none"
		if not found then
			table.insert(errs, name .. ": lemminx reported no error for a mismatched end tag")
		end
		vim.cmd("edit!")
	end

	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local copy = dir .. "/" .. name
	vim.fn.writefile(vim.fn.readfile(fixture), copy)
	open(copy, "xaml", xaml_lsp)
	local odd = [[            <Button   Content="Cancel"   Width="80"/>]]
	vim.api.nvim_buf_set_lines(0, -3, -3, false, { odd })
	local want = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local wrote, write_err = pcall(vim.cmd, "silent write")
	local got = vim.fn.readfile(copy)
	results.save = wrote and vim.deep_equal(got, want) and "kept" or "changed"
	if not wrote then
		table.insert(errs, (name .. ": :write threw: %s"):format(tostring(write_err):gsub("\n.*", "")))
	elseif results.save ~= "kept" then
		table.insert(errs, name .. ": saving reformatted the file")
	end
	vim.api.nvim_buf_delete(0, { force = true })
	vim.fn.delete(dir, "rf")

	io.stderr:write(("  %-18s highlight=%s diagnostic=%s save=%s\n"):format(
		name,
		results.highlight or "-",
		results.diagnostic or "-",
		results.save
	))
end
check_xaml("MainWindow.xaml")
check_xaml("MainWindow.axaml")

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

-- `g=` is mini.operators' evaluate: it runs the operated-on text as Lua. Any
-- buffer that is not Lua -- markdown prose, most of all -- is a syntax or
-- runtime error, which is the normal outcome of a mistyped `g=`, not a defect.
-- It used to escape the operator as E5108 with a full stack traceback across
-- the message area. The config now catches it and reports the message through
-- vim.notify instead. Both halves are checked here, because either one alone
-- passes against the broken config: swallowing the error silently would also
-- stop the throw, and a report that still carries the traceback is the symptom
-- this exists to prevent.
--
-- vim.notify is swapped for a local collector for the duration, so the
-- expected ERROR does not land in `errs` as a finding of its own.
local function check_evaluate_on_prose()

-- The other half of the same wrapper: catching the failure must not cost the
-- feature. Valid Lua still evaluates and still replaces the line.
local function check_evaluate_on_lua()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local scratch = dir .. "/scratch.lua"
	vim.fn.writefile({ "1 + 1" }, scratch)
	open(scratch, "lua", nil)

	local ok, err = pcall(vim.cmd, "normal g==")
	if not ok then
		table.insert(errs, ("g== on Lua threw: %s"):format(tostring(err):gsub("\n.*", "")))
		return
	end

	local got = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
	if got ~= "2" then
		table.insert(errs, ("g== on Lua gave %q, expected \"2\""):format(got))
	end

	io.stderr:write(("  %-18s g== -> %s\n"):format("scratch.lua", got))
end
check_evaluate_on_lua()
	open(config .. "/verify/fixture-md/note.md", "markdown", nil)

	local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local captured = {}
	local outer_notify = vim.notify
	vim.notify = function(msg, level, _)
		table.insert(captured, { msg = tostring(msg), level = level })
	end
	local ok, err = pcall(vim.cmd, "normal g=ip")
	vim.notify = outer_notify

	if not ok then
		table.insert(errs, ("g= on prose threw: %s"):format(tostring(err):gsub("\n.*", "")))
	end

	local reported
	for _, note in ipairs(captured) do
		if note.level == vim.log.levels.ERROR then
			reported = note.msg
		end
	end

	if not reported then
		table.insert(errs, "g= on prose reported no error through vim.notify")
	else
		if reported:find("stack traceback", 1, true) or reported:find("\n") then
			table.insert(errs, ("g= error report is not a single line: %q"):format(reported:sub(1, 120)))
		end
		if not reported:find("Heading", 1, true) then
			table.insert(errs, ("g= error report lost the Lua message: %q"):format(reported:sub(1, 120)))
		end
	end

	-- A failed evaluation leaves the text alone; it does not half-replace it.
	local after = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	if table.concat(before, "\n") ~= table.concat(after, "\n") then
		table.insert(errs, "g= on prose changed the buffer despite failing")
	end

	io.stderr:write(("  %-18s g= reported=%s\n"):format("note.md", reported and "yes" or "no"))
end
check_evaluate_on_prose()

-- Git on a Windows drive, on WSL. init.lua puts ~/.local/lib/wsl-git first on
-- PATH; that git hands a repository under /mnt/<drive> to Windows' git.exe and
-- writes the paths rev-parse prints back as WSL ones. Every plugin here that
-- reads git is run against a scratch repository in Windows' temp directory:
-- the status line's git band, gitsigns, oil-git-status, neogit's status and
-- diffview. A commit whose editor is a WSL command -- neogit's -- has to leave
-- git.exe, which cannot start it, for Linux's git. Skipped off WSL, or where
-- the wsl-git shim or git.exe is not installed.
local function check_windows_drive_git()
	local function say(text)
		io.stderr:write(("  %-18s %s\n"):format("wsl-git", text))
	end
	local function finding(text)
		table.insert(errs, "wsl-git: " .. text)
	end
	local shim = vim.fs.joinpath(vim.env.HOME or "", ".local/lib/wsl-git/git")
	local windows_git = vim.env.WINDOWS_GIT or "/mnt/c/Program Files/Git/cmd/git.exe"
	if not vim.env.WSL_DISTRO_NAME then
		return say("skipped: not WSL")
	end
	if vim.fn.executable(shim) ~= 1 or vim.fn.executable(windows_git) ~= 1 then
		return say("skipped: no wsl-git shim or no git.exe")
	end
	if vim.fn.exepath("git") ~= shim then
		return finding(("git on PATH is %s, not the wsl-git shim"):format(vim.fn.exepath("git")))
	end

	local temp = vim.system({ "/mnt/c/Windows/System32/cmd.exe", "/d", "/c", "echo %TEMP%" }, { cwd = "/mnt/c", text = true })
		:wait().stdout
		:gsub("%s+$", "")
	local temp_wsl = vim.system({ "wslpath", "-u", temp }, { text = true }):wait().stdout:gsub("%s+$", "")
	if not temp_wsl:match("^/mnt/%a/") then
		return finding(("Windows' temp directory %q is not on a drive"):format(temp))
	end
	local dir = ("%s/nvim-verify-git-%d"):format(temp_wsl, vim.fn.getpid())
	vim.fn.mkdir(dir, "p")
	local cleanup = dir

	local function git(args, env)
		return vim.system(vim.list_extend({ "git" }, args), { cwd = dir, text = true, env = env }):wait()
	end
	local function write(name, text)
		local file = assert(io.open(dir .. "/" .. name, "wb"))
		file:write(text)
		file:close()
	end
	local plain = function(s)
		return (s:gsub("%%#[^#]*#", ""))
	end
	local results = {}

	local ok, err = pcall(function()
		-- One commit, then one change of each kind the band counts: a modified
		-- file (with Windows line endings), a staged one and an untracked one.
		local identity = { "-c", "user.name=verify", "-c", "user.email=verify@invalid" }
		git({ "init", "-q", "-b", "main" })
		write("a.txt", "one\r\ntwo\r\n")
		git({ "add", "a.txt" })
		git(vim.list_extend(vim.deepcopy(identity), { "commit", "-q", "-m", "first" }))
		write("a.txt", "one\r\nTWO\r\n")
		write("c.txt", "staged\n")
		git({ "add", "c.txt" })
		write("b.txt", "untracked\n")

		-- Routing: this repository to git.exe, a Linux one and a WSL editor to
		-- Linux's git.
		if not git({ "version" }).stdout:find("windows", 1, true) then
			finding("a repository on a Windows drive did not get git.exe")
		end
		local linux = vim.system({ "git", "version" }, { cwd = config, text = true }):wait().stdout
		if linux:find("windows", 1, true) then
			finding("a Linux repository got git.exe")
		end
		if git({ "version" }, { GIT_EDITOR = "nvim --clean" }).stdout:find("windows", 1, true) then
			finding("a run with a WSL editor got git.exe, which cannot start it")
		end
		-- %TEMP% may hold a short 8.3 name (GAWLIK~1.MIG), which git reports
		-- long; go on with git's, the one a person's own path would match.
		local top = vim.trim(vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait().stdout)
		if not top:match("^/mnt/%a/") or vim.fn.filereadable(top .. "/b.txt") ~= 1 then
			error(("rev-parse --show-toplevel gave %q, not the repository as a WSL path"):format(top))
		end
		cleanup = dir
		dir = top

		-- The status line's git band and gitsigns, on the modified file.
		vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/a.txt"))
		local band = require("statusline_git")
		local want = { "main", "+1", "~1", "?1" }
		local got_band = vim.wait(30000, function()
			local text = plain(band.text())
			for _, part in ipairs(want) do
				if not text:find(part, 1, true) then
					return false
				end
			end
			return true
		end, 200)
		results.band = plain(band.text()):gsub("%s+", " ")
		if not got_band then
			finding(("git band shows %q, expected main +1 ~1 ?1"):format(results.band))
		end
		local gitsigns_ok = vim.wait(30000, function()
			return vim.b.gitsigns_head == "main" and #(require("gitsigns").get_hunks() or {}) == 1
		end, 200)
		results.gitsigns = ("head=%s hunks=%d"):format(tostring(vim.b.gitsigns_head), #(require("gitsigns").get_hunks() or {}))
		if not gitsigns_ok then
			finding("gitsigns: " .. results.gitsigns .. ", expected head=main hunks=1")
		end

		-- oil-git-status: a sign beside each of the three changed files.
		vim.cmd("edit " .. vim.fn.fnameescape("oil://" .. dir .. "/"))
		local ns = vim.api.nvim_get_namespaces()["oil-git-status"]
		local signs = 0
		vim.wait(30000, function()
			signs = 0
			for _, mark in ipairs(ns and vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true }) or {}) do
				if vim.trim(mark[4].sign_text or "") ~= "" then
					signs = signs + 1
				end
			end
			return signs >= 3
		end, 200)
		results.oil = ("signs=%d"):format(signs)
		if signs < 3 then
			finding(("oil-git-status set %d signs, expected one per changed file (3)"):format(signs))
		end

		-- neogit's status buffer.
		require("neogit").open({ cwd = dir, kind = "replace" })
		local sections = { "Untracked files (1)", "Unstaged changes (1)", "Staged changes (1)" }
		local neogit_ok = vim.wait(30000, function()
			local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
			for _, section in ipairs(sections) do
				if not text:find(section, 1, true) then
					return false
				end
			end
			return true
		end, 200)
		results.neogit = neogit_ok and "ok" or "missing sections"
		if not neogit_ok then
			finding("neogit's status lacks " .. table.concat(sections, ", "))
		end
		vim.cmd("enew")

		-- diffview: its file panel lists the modified and the staged file.
		vim.cmd("tcd " .. vim.fn.fnameescape(dir))
		vim.cmd("DiffviewOpen")
		local diffview_ok = vim.wait(30000, function()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_get_name(buf):find("DiffviewFilePanel", 1, true) then
					local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
					if text:find("a.txt", 1, true) and text:find("c.txt", 1, true) then
						return true
					end
				end
			end
			return false
		end, 200)
		-- Then both sides of the first file: closing while diffview still builds
		-- them is an error of its own ("Failed to create diff buffer").
		local sides = 0
		local sides_ok = diffview_ok
			and vim.wait(30000, function()
				sides = 0
				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
					local buf = vim.api.nvim_win_get_buf(win)
					if vim.wo[win].diff and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "one" then
						sides = sides + 1
					end
				end
				return sides >= 2
			end, 200)
		results.diffview = not diffview_ok and "files missing" or sides_ok and "ok" or ("sides=%d"):format(sides)
		if not diffview_ok then
			finding("diffview's file panel does not list a.txt and c.txt")
		elseif not sides_ok then
			finding(("diffview drew %d sides of a.txt, expected 2"):format(sides))
		end
		pcall(vim.cmd, "DiffviewClose")
		vim.cmd("tcd " .. vim.fn.fnameescape(config .. "/verify/fixture"))

		-- A commit whose editor is a WSL command, as neogit's is.
		local editor = [[sh -c 'echo verify-editor > "$1"' sh]]
		local commit = git(vim.list_extend(vim.deepcopy(identity), { "commit", "-q" }), { GIT_EDITOR = editor })
		local subject = vim.trim(vim.system({ windows_git, "log", "-1", "--format=%s" }, { cwd = dir, text = true }):wait().stdout)
		results.commit = commit.code == 0 and subject == "verify-editor" and "ok" or ("exit=%d subject=%q"):format(commit.code, subject)
		if results.commit ~= "ok" then
			finding("a commit with a WSL editor: " .. results.commit)
		end
	end)
	if not ok then
		finding(tostring(err):gsub("\n.*", ""))
	end

	-- Leave nothing behind: the buffers in the scratch repository, then it.
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(buf)
		if name:find(dir, 1, true) or name:find(cleanup, 1, true) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
	vim.fn.delete(cleanup, "rf")

	say(("band=%q gitsigns=%s oil=%s neogit=%s diffview=%s commit=%s"):format(
		results.band or "-",
		results.gitsigns or "-",
		results.oil or "-",
		results.neogit or "-",
		results.diffview or "-",
		results.commit or "-"
	))
end
check_windows_drive_git()

-- A bare `nvim` restores the cwd's auto-session session at VimEnter. One saved
-- before a directory moved `cd`s into a path that is gone and fails part-way,
-- which surfaced as an oil ENOENT traceback on every start in ~/dotfiles.
-- lua/session_guard.lua names that before the restore and asks what to do.
-- It only runs with a UI, so the checks call it directly with a stand-in for
-- vim.fn.confirm, against session files written into the sandbox's own
-- session directory.
local function check_session_guard()
	local guard = require("session_guard")
	local AutoSession = require("auto-session")
	local Config = require("auto-session.config")
	local Lib = require("auto-session.lib")

	-- The guard has to run before the restore, so its VimEnter autocmd has to
	-- be defined before auto-session's: autocmds for one event run in the
	-- order they were defined.
	local order = {}
	for i, au in ipairs(vim.api.nvim_get_autocmds({ event = "VimEnter" })) do
		if au.group_name and not order[au.group_name] then
			order[au.group_name] = i
		end
	end
	local g, a = order.session_stale_guard, order.auto_session_group
	if not g or not a then
		table.insert(errs, ("session guard: VimEnter autocmds missing (guard=%s auto-session=%s)"):format(g, a))
	elseif g > a then
		table.insert(errs, "session guard: VimEnter autocmd runs after auto-session's restore")
	end

	local root = vim.fn.tempname()
	local project = root .. "/project"
	vim.fn.mkdir(project, "p")
	local gone = root .. "/gone"

	-- missing_dirs: a `cd` and an oil buffer into gone directories, the same
	-- directory twice with and without a trailing slash, an escaped space,
	-- and lines that must not count -- an existing directory, plain files.
	local probe = root .. "/probe.vim"
	vim.fn.writefile({
		"cd " .. gone,
		"badd +1 init.lua",
		"file oil://" .. gone .. "/",
		"edit oil://" .. gone .. "/sub/",
		"lcd " .. root .. "/with\\ space",
		"tcd " .. project,
		"edit oil://" .. project .. "/",
	}, probe)
	local want = { gone, gone .. "/sub", root .. "/with space" }
	local got = guard.missing_dirs(probe)
	if not vim.deep_equal(got, want) then
		table.insert(errs, ("session guard: missing_dirs gave %s, expected %s"):format(vim.inspect(got), vim.inspect(want)))
	end

	local session = AutoSession.get_root_dir(true) .. Lib.escape_session_name(project) .. ".vim"
	local stale = { "cd " .. gone, "file oil://" .. gone .. "/" }
	local saved = { auto_restore = Config.auto_restore, auto_save = Config.auto_save }
	local function reset()
		Config.auto_restore, Config.auto_save = saved.auto_restore, saved.auto_save
	end

	-- Runs the guard against `lines` as project's session, answering the
	-- dialog with `answer`; returns the result, whether it asked, and what.
	local function run(lines, answer)
		vim.fn.delete(session)
		if lines then
			vim.fn.writefile(lines, session)
		end
		local asked
		local result = guard.guard({
			cwd = project,
			confirm = function(msg, choices)
				asked = { msg = msg, choices = choices }
				return answer
			end,
		})
		return result, asked
	end

	local function expect(name, result, want_result, cond, detail)
		if result ~= want_result then
			table.insert(errs, ("session guard %s: returned %q, expected %q"):format(name, result, want_result))
		elseif not cond then
			table.insert(errs, ("session guard %s: %s"):format(name, detail))
		end
	end

	local result, asked = run(nil, 1)
	expect("without a session", result, "none", not asked, "asked anyway")

	result, asked = run({ "cd " .. project, "edit oil://" .. project .. "/" }, 1)
	expect("on a fresh session", result, "fresh", not asked and vim.fn.filereadable(session) == 1, "asked or deleted")

	-- The dialog has to say what is wrong, not just that something is.
	result, asked = run(stale, 3)
	local msg = asked and asked.msg or ""
	expect(
		"restore anyway",
		result,
		"restore",
		msg:find("Stale session", 1, true)
			and msg:find(gone, 1, true)
			and msg:find(vim.fn.fnamemodify(session, ":t"), 1, true)
			and #vim.split(asked.choices, "\n") == 3
			and vim.fn.filereadable(session) == 1
			and Config.auto_restore == saved.auto_restore
			and Config.auto_save == saved.auto_save,
		("dialog %q, or the session or config changed"):format(msg:sub(1, 120))
	)

	-- Skip, and <Esc> (0) like it: keep the file, and keep this run from
	-- restoring it or saving over it.
	for _, answer in ipairs({ 2, 0 }) do
		result = run(stale, answer)
		expect(
			("skip (%d)"):format(answer),
			result,
			"skipped",
			vim.fn.filereadable(session) == 1 and Config.auto_restore == false and Config.auto_save == false,
			"session file gone, or auto_restore/auto_save left on"
		)
		reset()
	end

	result = run(stale, 1)
	expect("delete", result, "deleted", vim.fn.filereadable(session) == 0, "session file still there")

	vim.fn.delete(session)
	vim.fn.delete(root, "rf")
	reset()

	io.stderr:write(("  %-18s guard -> %s\n"):format("stale session", result))
end
check_session_guard()

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
