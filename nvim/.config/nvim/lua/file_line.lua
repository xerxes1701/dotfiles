-- Opens `path:line` names the way compilers, grep and Claude Code print them.
--
--   nvim lua/keymaps.lua:42        line 42
--   nvim lua/keymaps.lua:42:7      line 42, column 7
--   nvim lua/keymaps.lua:42:       grep -n style trailing colon
--   nvim lua/keymaps.lua:211-232   lines 211-232, selected linewise
--
-- Nvim reads such a name as a new file, so BufNewFile fires for it. When the
-- name minus its suffix is a readable file, that file replaces the empty
-- buffer and the cursor goes to the line. A file that really exists under the
-- full name never reaches BufNewFile and opens as itself.
local M = {}

-- The path, line, column and last line of a `path:line` name, or nil.
function M.parse(name)
	local path, first, last = name:match("^(.-):(%d+)%-(%d+)$")
	if path then
		return path, tonumber(first), nil, tonumber(last)
	end
	local col
	path, first, col = name:match("^(.-):(%d+):(%d+):?$")
	if path then
		return path, tonumber(first), tonumber(col), nil
	end
	path, first = name:match("^(.-):(%d+):?$")
	if path then
		return path, tonumber(first), nil, nil
	end
end

function M.open(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local path, first, col, last = M.parse(vim.api.nvim_buf_get_name(buf))
	if not path or path == "" or vim.fn.filereadable(path) == 0 then
		return
	end
	local win = vim.fn.bufwinid(buf)
	if win == -1 then
		return
	end

	vim.api.nvim_win_call(win, function()
		vim.cmd.edit(vim.fn.fnameescape(path))
		local count = vim.api.nvim_buf_line_count(0)
		first = math.min(first, count)
		vim.api.nvim_win_set_cursor(0, { first, math.max((col or 1) - 1, 0) })
		-- zv opens folds (origami) around the line; zz centres it.
		vim.cmd("normal! zvzz")
		if last and last > first then
			-- Anchor on the last line, so the cursor ends on the first.
			vim.cmd(("normal! %dGV%dG"):format(math.min(last, count), first))
		end
	end)

	-- The placeholder buffer is empty and unmodified; drop it so it does not
	-- linger in the buffer list or bufferline.
	if vim.api.nvim_buf_is_valid(buf) and vim.fn.bufwinid(buf) == -1 then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
end

function M.setup()
	vim.api.nvim_create_autocmd("BufNewFile", {
		group = vim.api.nvim_create_augroup("file_line", { clear = true }),
		pattern = "*:*",
		desc = "Open path:line names at the line",
		callback = function(args)
			-- Scheduled: replacing the buffer from inside its own BufNewFile
			-- leaves startup half-way through loading it.
			vim.schedule(function()
				M.open(args.buf)
			end)
		end,
	})
end

return M
