-- auto-closing HTML like tags
-- https://github.com/windwp/nvim-ts-autotag

return {
	"windwp/nvim-ts-autotag",
	commit = "8e1c0a3",
	opts = {
		opts = {
			enable_close = true, -- Auto close tags
			enable_rename = true, -- Auto rename pairs of tags
			enable_close_on_slash = true, -- Auto close on trailing </
		},
		per_filetype = {
			["html"] = {},
		},
	},
}
