return {
	"echasnovski/mini.nvim",
	commit = "1345d191bb3da9c7b0e977f4387c5761f9bff68d",
	config = function()
		require("mini.ai").setup()

		local operators = require("mini.operators")

		operators.setup({
			-- `g=` evaluates the operated-on text as Lua. On anything that is not
			-- Lua -- markdown prose, or a motion that grabbed more than intended --
			-- loadstring or the evaluated code itself throws, which is the ordinary
			-- outcome of a slip, not a defect. Unhandled, that error escapes the
			-- operator as E5108 with a stack traceback through mini's internals,
			-- and the one line that says what went wrong scrolls away with it.
			-- `evaluate.func` is the seam mini.operators offers for this: catch it,
			-- report the message alone, and return the text unchanged so a failed
			-- evaluation is a no-op instead of a half-replaced region.
			evaluate = {
				func = function(content)
					local ok, result = pcall(operators.default_evaluate_func, content)
					if ok then
						return result
					end
					local message = tostring(result):gsub("\n.*", "")
					vim.notify(message, vim.log.levels.ERROR, { title = "mini.operators: evaluate" })
					return content.lines
				end,
			},
		})

		require("mini.splitjoin").setup()
		--		require("mini.completion").setup()
	end,
}
