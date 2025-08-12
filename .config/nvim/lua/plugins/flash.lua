-- easy motion / jump any where
-- https://github.com/folke/flash.nvim

return {
	"folke/flash.nvim",
	tag = "v2.1.0",
	event = "VeryLazy",
	---@type Flash.Config
	opts = {
		modes = {
			treesitter = {
				highlight = {
					-- disable syntax highlighting while searching
					backdrop = true,
				},
				label = {
					rainbow = {
						enabled = true,
						shade = 5,
					},
				},
			},
		},
	},
  -- stylua: ignore
  keys = {
    { "<k7>", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    { "<F17>", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    { "<F18>", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  },
}
