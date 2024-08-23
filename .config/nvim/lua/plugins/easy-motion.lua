-- easy motion / jump any where
-- https://github.com/folke/flash.nvim

return {
  "folke/flash.nvim",
  tag = 'v2.1.0',
  event = "VeryLazy",
  ---@type Flash.Config
  opts = {
    modes = {
      treesitter = {
        label = {
          rainbow = {
            enabled = true,
            shade = 5,
          },
        },
        highlight = {
          -- disable syntax highlighting while searching
          backdrop = true,
        },
      },
    },
  },
  -- stylua: ignore
  keys = {
    { "m", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    { "M", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "<leader>jr", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "<leader>js", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  },
} 
