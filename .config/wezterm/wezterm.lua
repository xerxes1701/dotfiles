local w = require("wezterm")
local cfg = w.config_builder()
local act = w.action

function os_name()
	return package.config:sub(1, 1) == "\\" and "win" or "unix"
end

if os_name() == "win" then
	cfg.default_prog = { "ubuntu" }

	function is_wm_running()
		local command = "C:/code/CheckWM/bin/Debug/net8.0/CheckWM.exe"
		-- find a way to execute this, without a having a terminal window poping up
		-- return os.execute(command)
		return false
	end

	if is_wm_running() then
		cfg.window_decorations = "RESIZE"
	end
end

cfg.enable_tab_bar = false
-- cfg.window_background_opacity = 0
-- cfg.win32_system_backdrop = "Acrylic"
-- cfg.win32_system_backdrop = "Mica"
-- cfg.win32_system_backdrop = "Tabbed"
cfg.color_scheme = "Catppuccin Mocha" -- or Macchiato, Frappe, Latte

cfg.keys = {
	-- Bind 'Ctrl + B' to toggle window decoration to "RESIZE"
	{
		key = "b",
		mods = "CTRL",
		action = w.action_callback(function(win, pane)
			local overrides = win:get_config_overrides() or {}
			if overrides.window_decorations == "RESIZE" then
				overrides.window_decorations = "TITLE | RESIZE"
			else
				overrides.window_decorations = "RESIZE"
			end
			win:set_config_overrides(overrides)
		end),
	},
	-- paste from the clipboard
	{ key = "V", mods = "CTRL", action = act.PasteFrom("Clipboard") },

	-- paste from the primary selection
	{ key = "V", mods = "CTRL", action = act.PasteFrom("PrimarySelection") },
}

local dimmer = { brightness = 0.05 }

cfg.enable_scroll_bar = true
cfg.min_scroll_bar_height = "2cell"

-- cfg.background = {
-- 	{
-- 		source = {
-- 			File = w.home_dir .. "/.config/images/stones.jpg",
-- 		},
-- 		hsb = dimmer,
-- 		attachment = { Parallax = 0.1 },
-- 	},
-- 	{
-- 		source = {
-- 			File = w.home_dir .. "/.config/images/water.png",
-- 		},
-- 		hsb = dimmer,
-- 		attachment = { Parallax = 0.3 },
-- 	},
-- }

return cfg
