-- oil_status.lua
--
-- Hand-rolled "unsaved buffer" indicator for oil.nvim.
--
-- Git status (staged / unstaged / merge conflicts) is handled by the external
-- plugin `refractalize/oil-git-status.nvim` (see lua/plugins/oil-git-status.lua).
-- The one thing that plugin can't know about is Neovim's own state, so this
-- module adds a marker for files that are currently open in a *modified*
-- (unwritten) buffer.
--
-- It uses only oil's public API (get_entry_on_line / get_current_dir) plus the
-- events oil emits, so oil's source is never touched. The marker is rendered as
-- a sign; oil is configured with `signcolumn = "yes:3"` so it sits alongside the
-- two git-status columns.

local M = {}

local oil = require("oil")

local ns = vim.api.nvim_create_namespace("oil_status_unsaved")

local SIGN = "●"
local function define_highlights()
	vim.api.nvim_set_hl(0, "OilStatusUnsaved", { link = "DiagnosticInfo", default = true })
end

-- Absolute paths currently open in a modified (unwritten) file buffer.
local function unsaved_paths()
	local set = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified and vim.bo[buf].buftype == "" then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" then
				set[vim.fs.normalize(name)] = true
			end
		end
	end
	return set
end

local function refresh(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "oil" then
		return
	end
	local dir = oil.get_current_dir(bufnr)
	if not dir then
		return
	end
	dir = vim.fs.normalize(dir)

	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	local modified = unsaved_paths()
	if next(modified) == nil then
		return
	end

	for lnum = 1, vim.api.nvim_buf_line_count(bufnr) do
		local ok, entry = pcall(oil.get_entry_on_line, bufnr, lnum)
		if ok and entry and entry.name and entry.type ~= "directory" then
			local abspath = vim.fs.normalize(dir .. "/" .. entry.name)
			if modified[abspath] then
				vim.api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, 0, {
					sign_text = SIGN,
					sign_hl_group = "OilStatusUnsaved",
					-- Higher than oil-git-status (1/2) so it gets its own column.
					priority = 20,
				})
			end
		end
	end
end

M.refresh = refresh

function M.setup()
	define_highlights()

	local group = vim.api.nvim_create_augroup("OilStatusUnsaved", { clear = true })

	-- Recompute when an oil buffer is (re)displayed or after file operations.
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = { "OilEnter", "OilActionsPost", "OilMutationComplete" },
		callback = function(args)
			local buf = (args.data and args.data.buf) or vim.api.nvim_get_current_buf()
			vim.schedule(function()
				refresh(buf)
			end)
		end,
	})

	-- Catch returning to an existing oil buffer (OilEnter may not re-fire).
	vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
		group = group,
		callback = function(args)
			if vim.bo[args.buf].filetype == "oil" then
				vim.schedule(function()
					refresh(args.buf)
				end)
			end
		end,
	})

	-- Keep the indicator live as buffers are modified / saved.
	vim.api.nvim_create_autocmd({ "BufModifiedSet", "BufWritePost" }, {
		group = group,
		callback = function()
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.bo[buf].filetype == "oil" then
					refresh(buf)
				end
			end
		end,
	})

	-- Re-assert the highlight link after a colorscheme change.
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = define_highlights,
	})
end

return M
