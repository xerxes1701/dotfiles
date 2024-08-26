-- highlights all occurences of the symbol currently under the cursor
-- https://github.com/RRethy/vim-illuminate

return {
	"RRethy/vim-illuminate",
	config = function()
		require("illuminate").configure({})
	end,
}
