-- Diagnostics Hydra (body `<leader>ld`): severity-filter + direction navigation.
-- Extracted from lua/plugins/hydra.lua.
--
-- State is closure-persisted so scope/filter are remembered across invocations.

local M = {}

function M.setup()
	local Hydra = require("hydra")

	local severity = vim.diagnostic.severity
	local diag_state = { scope = "buffer" }

	local function get_diags(sev)
		local gopts = {}
		if sev then
			gopts.severity = sev
		end
		local buf = diag_state.scope == "buffer" and 0 or nil
		local diags = vim.diagnostic.get(buf, gopts)
		table.sort(diags, function(a, b)
			if a.bufnr ~= b.bufnr then
				return a.bufnr < b.bufnr
			end
			if a.lnum ~= b.lnum then
				return a.lnum < b.lnum
			end
			return a.col < b.col
		end)
		return diags
	end

	-- Positioning is delegated to vim.diagnostic.jump: it resolves the diagnostic's
	-- tracking extmark, so it follows edits instead of trusting the stored lnum (which
	-- goes stale, and out of range, when the buffer shrinks). It also opens folds,
	-- pushes a jumplist mark and schedules the float. Buffer switching is ours: jump
	-- only moves the cursor in the current window.
	local function goto_diag(diag)
		if not diag then
			vim.notify("No diagnostics to move to", vim.log.levels.WARN)
			return
		end
		if diag.bufnr then
			if not vim.api.nvim_buf_is_valid(diag.bufnr) then
				vim.notify("Diagnostic's buffer no longer exists", vim.log.levels.WARN)
				return
			end
			if diag.bufnr ~= vim.api.nvim_get_current_buf() then
				vim.api.nvim_set_current_buf(diag.bufnr)
			end
		end
		local ok = pcall(vim.diagnostic.jump, {
			diagnostic = diag,
			on_jump = function(_, bufnr)
				vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
			end,
		})
		if not ok then
			-- jump still raises "Invalid cursor line" when the tracked position lands
			-- one past the last line, i.e. the diagnostic's range was deleted and the
			-- server has not republished yet. Clamp rather than leave an uncaught
			-- error inside the hydra head.
			local lnum = math.min(diag.lnum + 1, vim.api.nvim_buf_line_count(0))
			pcall(vim.api.nvim_win_set_cursor, 0, { lnum, 0 })
			vim.notify("Stale diagnostic position; jumped to nearest line", vim.log.levels.WARN)
		end
	end

	-- tuple comparison over (bufnr, lnum, col)
	local function is_after(d, buf, l, c)
		if d.bufnr ~= buf then
			return d.bufnr > buf
		end
		if d.lnum ~= l then
			return d.lnum > l
		end
		return d.col > c
	end

	local function is_before(d, buf, l, c)
		if d.bufnr ~= buf then
			return d.bufnr < buf
		end
		if d.lnum ~= l then
			return d.lnum < l
		end
		return d.col < c
	end

	local function diag_nav(forward, sev)
		return function()
			local diags = get_diags(sev)
			if #diags == 0 then
				goto_diag(nil)
				return
			end
			local buf = vim.api.nvim_get_current_buf()
			local cur = vim.api.nvim_win_get_cursor(0)
			local l, c = cur[1] - 1, cur[2]
			if forward then
				for _, d in ipairs(diags) do
					if is_after(d, buf, l, c) then
						goto_diag(d)
						return
					end
				end
				goto_diag(diags[1]) -- wrap to first
			else
				for i = #diags, 1, -1 do
					if is_before(diags[i], buf, l, c) then
						goto_diag(diags[i])
						return
					end
				end
				goto_diag(diags[#diags]) -- wrap to last
			end
		end
	end

	local function diag_edge(last)
		return function()
			local diags = get_diags()
			if #diags == 0 then
				goto_diag(nil)
				return
			end
			goto_diag(last and diags[#diags] or diags[1])
		end
	end

	local function echo_state()
		vim.api.nvim_echo({
			{ "diagnostics ", "Title" },
			{ "[scope: " .. diag_state.scope .. "]", "Comment" },
		}, false, {})
	end

	local function toggle_scope()
		diag_state.scope = diag_state.scope == "buffer" and "project" or "buffer"
		echo_state()
	end

	local function toggle_virtual_lines()
		local nc = not vim.diagnostic.config().virtual_lines
		vim.diagnostic.config({ virtual_lines = nc })
	end

	-- Both flags are global (lspconfig.lua honours them on LspAttach), so the toggle
	-- has to be global too: omitting bufnr makes enable() walk every attached buffer.
	-- `~= false` treats an unset flag as on, matching the default set on attach.
	local function toggle_codelens()
		vim.g.codelens_enabled = not (vim.g.codelens_enabled ~= false)
		vim.lsp.codelens.enable(vim.g.codelens_enabled)
	end

	local function toggle_inlay_hints()
		vim.g.inlay_hints_enabled = not (vim.g.inlay_hints_enabled ~= false)
		vim.lsp.inlay_hint.enable(vim.g.inlay_hints_enabled)
	end

	local diag_hint = [[
 _d_/_D_: next/prev diagnostic   _}_/_{_: last/first
 _e_/_E_: next/prev error   _w_/_W_: next/prev warning
 _i_/_I_: next/prev info    _h_/_H_: next/prev hint
 _b_: toggle scope (buffer/project)
 _x_/_X_: Trouble diagnostics workspace/buffer
 _tv_/_tc_/_ti_: toggle virtual_lines/codelens/inlay
 _q_/_<Esc>_: exit
]]

	Hydra({
		name = "diagnostics",
		mode = "n",
		body = "<leader>ld",
		hint = diag_hint,
		config = {
			color = "red",
			invoke_on_body = true,
			hint = {
				float_opts = { border = "rounded" },
			},
			on_enter = echo_state,
		},
		heads = {
			{ "d", diag_nav(true), { desc = "next" } },
			{ "D", diag_nav(false), { desc = "prev" } },
			{ "}", diag_edge(true), { desc = "last" } },
			{ "{", diag_edge(false), { desc = "first" } },

			{ "e", diag_nav(true, severity.ERROR), { desc = "next error" } },
			{ "E", diag_nav(false, severity.ERROR), { desc = "prev error" } },
			{ "w", diag_nav(true, severity.WARN), { desc = "next warning" } },
			{ "W", diag_nav(false, severity.WARN), { desc = "prev warning" } },
			{ "i", diag_nav(true, severity.INFO), { desc = "next info" } },
			{ "I", diag_nav(false, severity.INFO), { desc = "prev info" } },
			{ "h", diag_nav(true, severity.HINT), { desc = "next hint" } },
			{ "H", diag_nav(false, severity.HINT), { desc = "prev hint" } },

			{ "b", toggle_scope, { desc = "toggle scope" } },

			{ "x", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Trouble (workspace)", silent = true } },
			{ "X", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Trouble (buffer)", silent = true } },

			{ "tv", toggle_virtual_lines, { desc = "toggle virtual_lines" } },
			{ "tc", toggle_codelens, { desc = "toggle codelens" } },
			{ "ti", toggle_inlay_hints, { desc = "toggle inlay hints" } },

			{ "q", nil, { exit = true, desc = "exit" } },
			{ "<Esc>", nil, { exit = true, desc = "exit" } },
		},
	})
end

return M
