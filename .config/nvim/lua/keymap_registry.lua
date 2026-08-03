-- keymap_registry.lua
--
-- Records which plugin / config file defined each keymap, so we can offer a
-- two-stage Telescope picker: first pick a plugin, then pick one of the
-- keymaps that plugin introduced.
--
-- Neovim does not natively track the plugin that owns a keymap (the `sid`
-- field is unreliable under lazy.nvim), so we install thin shims over the
-- mapping APIs *before plugins load* and remember the caller's source file
-- via debug.getinfo. lazy.nvim `keys = {}` specs are merged in at query time,
-- since those maps are created by lazy's own handler rather than the plugin.

local M = {}

-- list of { mode, lhs, rhs, desc, source, plugin }
M.records = {}

-- Runtime wrapper sources we must ignore, so a `vim.keymap.set` call is
-- attributed to the real caller and not counted twice via nvim_set_keymap.
local function is_wrapper(source)
	return source:match("vim/keymap%.lua$")
		or source:match("vim/_editor%.lua$")
		or source:match("vim/shared%.lua$")
end

-- Turn a debug source ("@/path/to/file.lua") into (plugin_label, clean_path).
function M.derive(source)
	local path = (source or ""):gsub("^@", "")

	local plugin = path:match("/lazy/([^/]+)/")
	if plugin then
		return plugin, path
	end

	local spec = path:match("/nvim/lua/plugins/([^/]+)%.lua$")
	if spec then
		return spec, path
	end

	if
		path:match("/nvim/lua/keymaps%.lua$")
		or path:match("/nvim/lua/defaults")
		or path:match("/nvim/init%.lua$")
	then
		return "core config", path
	end

	local other = path:match("/nvim/lua/([^/.]+)")
	if other then
		return other, path
	end

	return "unknown", path
end

local function record(mode, lhs, rhs, opts, level)
	if type(lhs) ~= "string" then
		return
	end
	local info = debug.getinfo(level + 1, "S") or {}
	local source = info.source or "?"
	if is_wrapper(source) then
		return
	end
	local plugin, path = M.derive(source)

	local modes = type(mode) == "table" and mode or { mode }
	local desc = type(opts) == "table" and opts.desc or nil
	for _, m in ipairs(modes) do
		table.insert(M.records, {
			mode = m == "" and " " or m,
			lhs = lhs,
			rhs = type(rhs) == "string" and rhs or "<lua>",
			desc = desc,
			source = path,
			plugin = plugin,
		})
	end
end

local installed = false

function M.setup()
	if installed then
		return
	end
	installed = true

	local orig_set = vim.keymap.set
	vim.keymap.set = function(mode, lhs, rhs, opts)
		record(mode, lhs, rhs, opts, 2)
		return orig_set(mode, lhs, rhs, opts)
	end

	local orig_api = vim.api.nvim_set_keymap
	vim.api.nvim_set_keymap = function(mode, lhs, rhs, opts)
		record(mode, lhs, rhs, opts, 2)
		return orig_api(mode, lhs, rhs, opts)
	end

	local orig_buf = vim.api.nvim_buf_set_keymap
	vim.api.nvim_buf_set_keymap = function(buf, mode, lhs, rhs, opts)
		record(mode, lhs, rhs, opts, 2)
		return orig_buf(buf, mode, lhs, rhs, opts)
	end
end

-- Build { plugin_name = { record, ... } }, merging captured records with
-- lazy.nvim's declarative `keys` specs.
function M.build_index()
	local by_plugin = {}
	local function add(plugin, rec)
		by_plugin[plugin] = by_plugin[plugin] or {}
		table.insert(by_plugin[plugin], rec)
	end

	for _, r in ipairs(M.records) do
		-- lazy sets `keys = {}` maps itself; re-attributed below via specs.
		if r.plugin ~= "lazy.nvim" then
			add(r.plugin, r)
		end
	end

	local ok, lazy = pcall(require, "lazy")
	if ok then
		for _, p in ipairs(lazy.plugins()) do
			for _, k in ipairs(p.keys or {}) do
				local lhs = type(k) == "table" and (k[1] or k.lhs) or k
				if type(lhs) == "string" then
					local mode = type(k) == "table" and (k.mode or "n") or "n"
					if type(mode) == "table" then
						mode = table.concat(mode, ",")
					end
					add(p.name, {
						mode = mode,
						lhs = lhs,
						rhs = type(k) == "table" and tostring(k[2] or "<lua>") or "<lua>",
						desc = type(k) == "table" and k.desc or nil,
						source = "lazy keys spec",
						plugin = p.name,
					})
				end
			end
		end
	end

	return by_plugin
end

-- Stage 2: pick a keymap belonging to `plugin` and trigger it on <CR>.
local function pick_keymaps(plugin, records)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	table.sort(records, function(a, b)
		return a.lhs < b.lhs
	end)

	pickers
		.new({}, {
			prompt_title = "Keymaps: " .. plugin,
			finder = finders.new_table({
				results = records,
				entry_maker = function(r)
					local display = string.format("%-6s %-24s %s", r.mode, r.lhs, r.desc or r.rhs or "")
					return { value = r, display = display, ordinal = r.lhs .. " " .. (r.desc or "") }
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local sel = action_state.get_selected_entry()
					if not sel then
						return
					end
					local keys = vim.api.nvim_replace_termcodes(sel.value.lhs, true, false, true)
					vim.api.nvim_feedkeys(keys, "t", true)
				end)
				return true
			end,
		})
		:find()
end

-- Stage 1: pick a plugin.
function M.pick()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local by_plugin = M.build_index()
	local names = {}
	for name in pairs(by_plugin) do
		table.insert(names, name)
	end
	table.sort(names)

	pickers
		.new({}, {
			prompt_title = "Keymaps by plugin",
			finder = finders.new_table({
				results = names,
				entry_maker = function(name)
					local count = #by_plugin[name]
					return {
						value = name,
						display = string.format("%-28s %d", name, count),
						ordinal = name,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local sel = action_state.get_selected_entry()
					if not sel then
						return
					end
					pick_keymaps(sel.value, by_plugin[sel.value])
				end)
				return true
			end,
		})
		:find()
end

return M
