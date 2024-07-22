-- git ui
-- https://github.com/NeogitOrg/neogit

return {
  'NeogitOrg/neogit',
	tag = 'v0.0.1', -- neovim 0.9.x compatible
	dependencies = {
	  'nvim-lua/plenary.nvim',
		'sindrets/diffview.nvim',
		'nvim-telescope/telescope.nvim',
	},
	config = function()
	  require("neogit").setup({
      integrations = { 
        diffview = true 
      }
    })
  end,
}

