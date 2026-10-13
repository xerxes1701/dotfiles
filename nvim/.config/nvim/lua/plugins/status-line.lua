-- status line
-- https://github.com/nvim-lualine/lualine.nvim
--
-- Chevrons in muted colours, like the shell prompt and Claude Code's status
-- line: rounded at both ends, the mode's coloured band first, then two dark
-- greys stepping down into the transparent middle, and the right side its
-- mirror. A coloured band has a contrast of 2.0 against the terminal's One
-- Half Dark background and its text is the band's own hue at 4.6 against it;
-- the texts on the dark greys reach 4.6 against the lighter of them. The git
-- band shows what the prompt's does, see lua/statusline_git.lua.

local CAP_LEFT, ARROW_RIGHT = "\u{e0b6}", "\u{e0b0}"
local ARROW_LEFT, CAP_RIGHT = "\u{e0b2}", "\u{e0b4}"

-- One coloured band per mode; visual's purple is derived like the others.
local MODES = {
	normal = { bg = "#485C6D", fg = "#C1D5E7" }, -- blue
	insert = { bg = "#486040", fg = "#B5DEA7" }, -- green
	visual = { bg = "#6D4E76", fg = "#E3C9EA" }, -- purple
	replace = { bg = "#764F54", fg = "#EBCACF" }, -- red
	command = { bg = "#605940", fg = "#DED2A8" }, -- yellow
	terminal = { bg = "#415E62", fg = "#ABDADF" }, -- cyan
}
local SURFACE, DEEP = "#3E4451", "#353A45"
local TEXT = {
	Subtext = "#AFB3BB",
	Red = "#D5A7AB",
	Orange = "#C9AE93",
	Yellow = "#D7C198",
	Green = "#A1BA8E",
	Cyan = "#8CBBC1",
	Blue = "#8FB7D7",
	Purple = "#C9A7D3",
}

-- Sections a and b (z and y on the right) are the mode's band and the lighter
-- grey; c is the transparent middle, so the darker grey is coloured per
-- component.
local theme = {
	normal = { b = { bg = SURFACE, fg = TEXT.Subtext }, c = { bg = "NONE", fg = TEXT.Subtext } },
	inactive = {
		a = { bg = SURFACE, fg = TEXT.Subtext },
		b = { bg = DEEP, fg = TEXT.Subtext },
		c = { bg = "NONE", fg = TEXT.Subtext },
	},
}
for mode, band in pairs(MODES) do
	theme[mode] = theme[mode] or {}
	theme[mode].a = { bg = band.bg, fg = band.fg, gui = "bold" }
end

-- A component on the darker grey, in the text colour given or the quiet one.
local function deep(component, fg)
	component.color = { bg = DEEP, fg = fg or TEXT.Subtext }
	return component
end

-- An empty band that only draws the darker grey's arrow into the middle, so
-- the arrow is there whichever of the band's components are empty.
local function fade(separator)
	return {
		function()
			return ""
		end,
		draw_empty = true,
		padding = 0,
		color = { bg = DEEP },
		separator = separator,
	}
end

-- An empty band in the inactive line, just its arrow, so it steps down too.
local function step()
	return {
		function()
			return ""
		end,
		draw_empty = true,
		padding = 0,
	}
end

return {
	"nvim-lualine/lualine.nvim",
	commit = "47f91c4",
	dependencies = "nvim-web-devicons",
	event = "VimEnter",
	config = function()
		local lazy_status = require("lazy.status")
		local git = require("statusline_git")
		local lualine = require("lualine")

		git.setup({
			bg = SURFACE,
			colors = TEXT,
			on_change = function()
				lualine.refresh({ place = { "statusline" } })
			end,
		})

		lualine.setup({
			options = {
				theme = theme,
				component_separators = "",
				section_separators = { left = ARROW_RIGHT, right = ARROW_LEFT },
			},
			sections = {
				lualine_a = { { "mode", separator = { left = CAP_LEFT, right = ARROW_RIGHT } } },
				-- Empty outside a repository, where its band is only an arrow.
				lualine_b = { { git.text, padding = { left = 0, right = 1 }, draw_empty = true } },
				lualine_c = {
					deep({ "filename" }, TEXT.Blue),
					deep({
						"diagnostics",
						diagnostics_color = {
							error = { fg = TEXT.Red },
							warn = { fg = TEXT.Yellow },
							info = { fg = TEXT.Blue },
							hint = { fg = TEXT.Cyan },
						},
					}),
					fade({ right = ARROW_RIGHT }),
				},
				lualine_x = {
					fade({ left = ARROW_LEFT }),
					deep({
						function()
							return lazy_status.updates() or ""
						end,
						cond = lazy_status.has_updates,
					}, TEXT.Orange),
					deep({ "encoding" }),
					deep({ "fileformat" }),
					-- In the band's text colour: many of nvim-web-devicons' own icon
					-- colours are far below 4.6 on the grey.
					deep({ "filetype", colored = false }),
				},
				lualine_y = { "progress" },
				lualine_z = { { "location", separator = { left = ARROW_LEFT, right = CAP_RIGHT } } },
			},
			inactive_sections = {
				lualine_a = { { "filename", separator = { left = CAP_LEFT, right = ARROW_RIGHT } } },
				lualine_b = { step() },
				lualine_c = {},
				lualine_x = {},
				lualine_y = { step() },
				lualine_z = { { "location", separator = { left = ARROW_LEFT, right = CAP_RIGHT } } },
			},
		})
	end,
}
