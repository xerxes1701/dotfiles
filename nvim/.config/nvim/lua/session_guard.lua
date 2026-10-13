-- Names a stale auto-session session before it is restored, and offers to
-- delete it.
--
-- A session file is a vim script that `cd`s into the directory it was saved
-- from and reopens its buffers there. When that directory has since moved or
-- gone -- the dotfiles repo once kept nvim in .config/nvim at its top level --
-- sourcing the file fails part-way: auto-session reports a generic "Error
-- restoring session" and oil buffers in the session raise ENOENT tracebacks.
--
-- auto-session's hooks cannot do this: pre_restore_cmds gets no session path
-- and cannot cancel the restore. So lua/plugins/session.lua runs M.guard from
-- a VimEnter autocmd registered before auto-session's own.
local M = {}

-- The directories a session file needs that no longer exist, as ~-paths.
function M.missing_dirs(session_path)
	local ok, lines = pcall(vim.fn.readfile, session_path)
	if not ok then
		return {}
	end

	local missing, seen = {}, {}
	local function check(dir)
		dir = vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")
		if not seen[dir] and vim.fn.isdirectory(dir) == 0 then
			seen[dir] = true
			table.insert(missing, vim.fn.fnamemodify(dir, ":~"))
		end
	end

	for _, line in ipairs(lines) do
		-- session files escape spaces in paths with a backslash
		local cd = line:match("^[lt]?cd (.+)$")
		local oil = line:match("oil://(/.+)$")
		if cd then
			check(vim.fn.expand((cd:gsub("\\ ", " "))))
		elseif oil then
			check(oil)
		end
	end
	return missing
end

-- Checks the session auto-session would restore for `opts.cwd` (default: the
-- global cwd) and, when it is stale, asks through `opts.confirm` (default:
-- vim.fn.confirm, which takes the same arguments). Returns what happened:
-- "none", "fresh", "deleted", "skipped" or "restore".
function M.guard(opts)
	opts = opts or {}
	local confirm = opts.confirm or vim.fn.confirm

	local AutoSession = require("auto-session")
	local Config = require("auto-session.config")
	local Lib = require("auto-session.lib")

	local cwd = opts.cwd or vim.fn.getcwd(-1, -1)
	local session_path = AutoSession.get_root_dir(true) .. Lib.escape_session_name(cwd) .. ".vim"
	if vim.fn.filereadable(session_path) == 0 then
		return "none"
	end

	local missing = M.missing_dirs(session_path)
	if #missing == 0 then
		return "fresh"
	end

	local msg = ("Stale session for %s\n\nIt was saved when these directories existed:\n  %s\n\n"
		.. "Restoring it would fail part-way.\nSession file: %s"):format(
		vim.fn.fnamemodify(cwd, ":~"),
		table.concat(missing, "\n  "),
		vim.fn.fnamemodify(session_path, ":~")
	)
	local choice = confirm(msg, "&Delete session\n&Skip restore\n&Restore anyway", 1, "Warning")

	if choice == 1 then
		-- auto-session then finds no session for cwd, starts clean, and saves
		-- a fresh one on exit
		AutoSession.DeleteSessionFile(session_path, cwd)
		return "deleted"
	elseif choice == 3 then
		return "restore"
	end
	-- Skip, or <Esc> (0): leave the file alone, and don't let this run
	-- overwrite it either
	Config.auto_restore = false
	Config.auto_save = false
	return "skipped"
end

return M
