local w = require 'wezterm'
local cfg = w.config_builder()

function os_name()
    return package.config:sub(1,1) == "\\" and "win" or "unix"
end

--cfg.color_scheme = 'AdventureTime'
if os_name() == 'win' then
	cfg.default_prog = { 'ubuntu' }
end

cfg.enable_tab_bar = false
--cfg.window_decorations = "RESIZE"
cfg.window_background_opacity = 0
cfg.win32_system_backdrop = "Acrylic"
cfg.win32_system_backdrop = "Mica"
cfg.win32_system_backdrop = "Tabbed"

print 'test'

return cfg
