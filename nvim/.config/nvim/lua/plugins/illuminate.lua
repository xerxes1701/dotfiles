-- highlights all occurences of the symbol currently under the cursor
-- https://github.com/RRethy/vim-illuminate

return {
	"RRethy/vim-illuminate",
	commit = "0d1e936",
	config = function()
		require("illuminate").configure({})
	end,
}
