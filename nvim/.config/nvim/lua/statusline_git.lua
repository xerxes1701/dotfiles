-- The status line's git band: what the shell prompt's git badge shows, in the
-- same signs and colours. Branch, short commit and the operation in progress,
-- then the counters of starship's git_status, counted the way it counts them.
--
-- git runs in the background and the band shows the last result until the next
-- one arrives: at most one `git status` per repository at a time, a refresh
-- asked for during one only queues a single rerun, and a burst of events
-- starts one refresh. A slow repository (a large one, or one on /mnt/c) just
-- shows its last result for longer.

local M = {}

local uv = vim.uv

local DEBOUNCE = 100
-- How often to look for changes made outside Neovim, and how many times its
-- own duration a status has to have been finished before the timer runs it
-- again, so a slow repository is not scanned around the clock.
local TICK = 10000
local SPACING = 10
-- As long as the prompt's background scan may take.
local TIMEOUT = 300000

local ICON = { branch = "\u{f418}", commit = "\u{f417}", ahead = "\u{f19b2}", behind = "\u{f19b3}" }

-- starship git_status's counters, in its order, with its signs and colours.
local COUNTERS = {
	{ "conflicted", "=", "Orange" },
	{ "staged", "+", "Green" },
	{ "renamed", "»", "Purple" },
	{ "modified", "~", "Yellow" },
	{ "deleted", "-", "Red" },
	{ "typechanged", "t", "Purple" },
	{ "untracked", "?", "Subtext" },
	{ "stashed", "≡", "Blue" },
}

local opts = {}
local focused = true
-- directory -> { root, stale }, learned from `git rev-parse`
local dirs = {}
local resolving = {}
-- root -> { root, gitdir, text, running, rerun, took, finished }
local repos = {}

local function hl(name)
	return "%#GitBand" .. name .. "#"
end

local function set_highlights()
	for name, fg in pairs(opts.colors) do
		vim.api.nvim_set_hl(0, "GitBand" .. name, { fg = fg, bg = opts.bg })
	end
	vim.api.nvim_set_hl(0, "GitBandState", { fg = opts.colors.Orange, bg = opts.bg, bold = true })
end

-- Spawning fails outright when git is missing; that is just no repository.
local function run(cmd, on_exit)
	local ok = pcall(vim.system, cmd, { text = true, timeout = TIMEOUT }, on_exit)
	if not ok then
		on_exit({ code = -1, stdout = "" })
	end
end

-- The directory whose repository the band shows: the buffer's file's, the one
-- an oil buffer lists, else the working directory. A file inside .git (a
-- commit message being written) belongs to the repository around it.
local function buffer_dir(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	local dir
	if vim.bo[buf].filetype == "oil" then
		dir = require("oil").get_current_dir(buf)
	elseif vim.bo[buf].buftype == "" and name ~= "" then
		dir = vim.fn.fnamemodify(name, ":p:h")
	end
	dir = vim.fs.normalize(dir or uv.cwd())
	return dir:match("^(.*)/%.git$") or dir:match("^(.*)/%.git/") or dir
end

-- Counts entries as starship's git_status does: staged when the index side is
-- M, A or T, modified when the work tree side is M or A, deleted when either
-- side is D, typechanged when the work tree side is T; a rename also counts as
-- renamed, and an unmerged entry only as conflicted.
local function parse(out)
	local s = {}
	for _, counter in ipairs(COUNTERS) do
		s[counter[1]] = 0
	end
	for line in out:gmatch("[^\n]+") do
		local kind = line:sub(1, 1)
		if kind == "#" then
			local key, value = line:match("^# (%S+) (.*)$")
			if key == "branch.head" then
				s.head = value
			elseif key == "branch.oid" then
				s.oid = value
			elseif key == "branch.upstream" then
				s.upstream = value
			elseif key == "branch.ab" then
				local ahead, behind = value:match("^%+(%d+) %-(%d+)$")
				s.ahead, s.behind = tonumber(ahead), tonumber(behind)
			elseif key == "stash" then
				s.stashed = tonumber(value) or 0
			end
		elseif kind == "1" or kind == "2" then
			local x, y = line:sub(3, 3), line:sub(4, 4)
			s.staged = s.staged + ((x == "M" or x == "A" or x == "T") and 1 or 0)
			s.modified = s.modified + ((y == "M" or y == "A") and 1 or 0)
			s.deleted = s.deleted + ((x == "D" or y == "D") and 1 or 0)
			s.typechanged = s.typechanged + (y == "T" and 1 or 0)
			s.renamed = s.renamed + (kind == "2" and 1 or 0)
		elseif kind == "u" then
			s.conflicted = s.conflicted + 1
		elseif kind == "?" then
			s.untracked = s.untracked + 1
		end
	end
	return s
end

local function escape(text)
	return (text:gsub("%%", "%%%%"))
end

local function band(s, state)
	local parts = {}
	local function add(color, text)
		table.insert(parts, hl(color) .. " " .. escape(text))
	end
	-- starship names a detached HEAD "HEAD", and adds the upstream's branch
	-- when its name differs; the upstream comes as remote/branch, or bare
	-- when it is a local branch.
	local branch = s.head == "(detached)" and "HEAD" or s.head
	local remote = s.upstream and (s.upstream:match("^[^/]+/(.+)$") or s.upstream)
	add("Purple", ICON.branch .. " " .. branch .. (remote and remote ~= branch and ":" .. remote or ""))
	if s.oid and s.oid ~= "(initial)" then
		add("Yellow", ICON.commit .. " " .. s.oid:sub(1, 7))
	end
	if state then
		add("State", state)
	end
	for _, counter in ipairs(COUNTERS) do
		local name, sign, color = unpack(counter)
		if s[name] > 0 then
			add(color, sign .. s[name])
		end
	end
	if (s.ahead or 0) > 0 then
		add("Cyan", ICON.ahead .. s.ahead)
	end
	if (s.behind or 0) > 0 then
		add("Cyan", ICON.behind .. s.behind)
	end
	return table.concat(parts)
end

-- Async file system helpers for the state below. They run their callbacks
-- off the editor, so nothing in them may touch the editor's API.
local function list(dir, done)
	uv.fs_scandir(dir, function(_, handle)
		local names = {}
		while handle do
			local name = uv.fs_scandir_next(handle)
			if not name then
				break
			end
			names[name] = true
		end
		done(names)
	end)
end

local function read(path, done)
	uv.fs_open(path, "r", 438, function(_, fd)
		if not fd then
			return done(nil)
		end
		uv.fs_read(fd, 64, 0, function(_, data)
			uv.fs_close(fd, function() end)
			done(data)
		end)
	end)
end

-- starship's git_state label: the operation git is in the middle of, from the
-- files it keeps in its directory, checked in starship's order, and how far a
-- rebase has got.
local function read_state(gitdir, done)
	local function progress(current, total)
		read(gitdir .. "/" .. current, function(c)
			read(gitdir .. "/" .. total, function(t)
				local n, m = tonumber(vim.trim(c or "")), tonumber(vim.trim(t or ""))
				done(n and m and ("REBASING %d/%d"):format(n, m) or "REBASING")
			end)
		end)
	end
	list(gitdir, function(has)
		if has["rebase-apply"] then
			list(gitdir .. "/rebase-apply", function(apply)
				if apply.applying then
					done("AM")
				elseif apply.rebasing then
					progress("rebase-apply/next", "rebase-apply/last")
				else
					done("AM/REBASE")
				end
			end)
		elseif has["rebase-merge"] then
			progress("rebase-merge/msgnum", "rebase-merge/end")
		else
			done(
				has.CHERRY_PICK_HEAD and "CHERRY-PICKING"
					or has.MERGE_HEAD and "MERGING"
					or has.BISECT_LOG and "BISECTING"
					or has.REVERT_HEAD and "REVERTING"
					or nil
			)
		end
	end)
end

-- --no-optional-locks keeps `git status` from taking .git/index.lock, which
-- would make your own git commands fail while it runs.
local function scan(repo)
	if repo.running then
		repo.rerun = true
		return
	end
	repo.running, repo.rerun = true, false
	local started = uv.now()
	local cmd =
		{ "git", "--no-optional-locks", "-C", repo.root, "status", "--porcelain=v2", "--branch", "--show-stash" }
	run(cmd, function(out)
		read_state(repo.gitdir, function(state)
			vim.schedule(function()
				repo.running = false
				repo.finished = uv.now()
				repo.took = repo.finished - started
				if out.code == 0 then
					local text = band(parse(out.stdout), state)
					if text ~= repo.text then
						repo.text = text
						opts.on_change()
					end
				end
				if repo.rerun then
					scan(repo)
				end
			end)
		end)
	end)
end

-- The work tree and git directory `dir` is in. A new file's directory may not
-- exist yet; it is then in the repository around the nearest one that does.
local function resolve(dir, done)
	run({ "git", "-C", dir, "rev-parse", "--show-toplevel", "--absolute-git-dir" }, function(out)
		local root, gitdir = out.stdout:match("^([^\n]+)\n([^\n]+)")
		if out.code == 0 and root then
			return done(root, gitdir)
		end
		local parent = vim.fs.dirname(dir)
		uv.fs_stat(dir, function(_, stat)
			if stat or parent == dir then
				done(nil)
			else
				resolve(parent, done)
			end
		end)
	end)
end

-- Learns a directory's repository, once until something may have created or
-- removed one, then scans it. A directory outside any repository is asked
-- again each time, which is one quick git call.
local function refresh(dir)
	local known = dirs[dir]
	if known and not known.stale then
		return scan(repos[known.root])
	end
	if resolving[dir] then
		return
	end
	resolving[dir] = true
	resolve(dir, function(root, gitdir)
		vim.schedule(function()
			resolving[dir] = nil
			if not root then
				if dirs[dir] then
					dirs[dir] = nil
					opts.on_change()
				end
				return
			end
			root = vim.fs.normalize(root)
			repos[root] = repos[root] or { root = root }
			repos[root].gitdir = gitdir
			local moved = not known or known.root ~= root
			dirs[dir] = { root = root }
			if moved and repos[root].text then
				opts.on_change()
			end
			scan(repos[root])
		end)
	end)
end

local debounce, tick = uv.new_timer(), uv.new_timer()
local function request()
	debounce:start(DEBOUNCE, 0, function()
		vim.schedule(function()
			refresh(buffer_dir(vim.api.nvim_get_current_buf()))
		end)
	end)
end

--- The band's text for the current buffer: the last result, never waiting.
function M.text()
	local known = dirs[buffer_dir(vim.api.nvim_get_current_buf())]
	return known and repos[known.root].text or ""
end

--- opts.bg: the band's colour; opts.colors: the text colours by name (Purple,
--- Yellow, Orange, Green, Red, Subtext, Blue, Cyan); opts.on_change: redraws
--- the status line, called only when the text has changed.
function M.setup(o)
	opts = o
	set_highlights()

	local group = vim.api.nvim_create_augroup("statusline_git", { clear = true })
	local function on(events, callback, pattern)
		vim.api.nvim_create_autocmd(events, { group = group, pattern = pattern, callback = callback })
	end
	on("ColorScheme", set_highlights)
	on({ "BufEnter", "BufWritePost" }, request)
	-- Events after which a repository may have appeared or gone, so every
	-- directory's is looked up again.
	on({ "FocusGained", "DirChanged", "ShellCmdPost", "TermLeave", "TermClose" }, function()
		for _, known in pairs(dirs) do
			known.stale = true
		end
		request()
	end)
	on("FocusGained", function()
		focused = true
	end)
	on("FocusLost", function()
		focused = false
	end)
	on("User", request, { "GitSignsChanged", "Neogit*" })
	-- gitsigns also sends this after each pause in typing; an unsaved edit
	-- changes nothing git can see.
	on("User", function(args)
		local buf = args.data and args.data.buffer
		if not (buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified) then
			request()
		end
	end, "GitSignsUpdate")

	tick:start(TICK, TICK, function()
		vim.schedule(function()
			local known = dirs[buffer_dir(vim.api.nvim_get_current_buf())]
			local repo = known and repos[known.root]
			if focused and repo and repo.finished and uv.now() - repo.finished >= SPACING * repo.took then
				request()
			end
		end)
	end)

	request()
end

return M
