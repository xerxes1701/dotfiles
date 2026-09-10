-- seamless focus movement and resizing across nvim splits, tmux panes and herdr panes
-- https://github.com/mrjones2014/smart-splits.nvim
--
-- Replaces vim-tmux-navigator. That plugin only knew tmux, and it decided
-- whether a pane held nvim by matching `ps` output against a regex. This one
-- ships back-ends for both tmux and herdr, and both of them ask the editor
-- itself, so C-hjkl and C-arrows mean the same thing in nvim, tmux+nvim and
-- herdr+nvim. See ../../../../README.md, section "navigation".
-- Resize under herdr. smart-splits.nvim hands a resize to the multiplexer when
-- the nvim window has no split to resize in that direction, and it passes its
-- cell count straight through -- but `herdr pane resize --amount` is a fraction
-- of the split, so 3 reads as 300% and slams the split to its minimum. That is
-- the common case, not a corner: a single-window nvim pane is what a resize key
-- is usually pressed in. scripts/herdr-resize-pane.sh owns the conversion, for
-- this and for the herdr keybinding both, so the step is 3 cells everywhere.
--
-- The predicate is smart-splits.nvim's own, so this hands off in exactly the
-- cases where it would have.
local function resize(direction)
	local horizontal = direction == "left" or direction == "right"
	return function()
		local in_herdr = (vim.env.HERDR_ENV or "") ~= ""
		local win = require("smart-splits.win")
		local full = horizontal and win.is_full_width() or win.is_full_height()
		if in_herdr and full then
			vim.system({
				vim.fn.expand("~/dotfiles/scripts/herdr-resize-pane.sh"),
				direction,
				"--mux-only",
			})
			return
		end
		require("smart-splits")["resize_" .. direction]()
	end
end

return {
	"mrjones2014/smart-splits.nvim",
	commit = "5e92431aa7f5e618c2f6825f682df6d94f6e0a02",
	-- Deliberately not lazy-loaded. The tmux back-end sets the pane-local
	-- option @pane-is-vim when it loads and unsets it when nvim exits, and
	-- tmux's own C-hjkl bindings branch on that option. Under a lazy spec the
	-- option stays unset until something else triggers the load, so the first
	-- C-h in a fresh nvim would move the tmux pane instead of the split.
	lazy = false,
	opts = {
		-- multiplexer_integration is left unset on purpose. The plugin picks
		-- the back-end itself: herdr when HERDR_ENV is set, else tmux when
		-- TERM_PROGRAM is tmux. One spec therefore covers nvim on its own,
		-- tmux+nvim and herdr+nvim with no per-host branching.
		--
		-- 'stop' rather than the upstream default 'wrap': this is what
		-- vim-tmux-navigator did, and the tmux and herdr sides do not wrap
		-- either (@smart-splits_no_wrap in tmux.conf, and herdr-navigate.sh
		-- has no wrap at all). Anything else would make the edge behave
		-- differently depending on which app owns the pane you are leaving.
		at_edge = "stop",
		default_amount = 3,
	},
	keys = {
		-- Layer 0: no prefix, level-transparent. nvim splits and multiplexer
		-- panes are one grid; these keys cross the boundary in both directions.
		{ "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "goto left pane/split" },
		{ "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "goto lower pane/split" },
		{ "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "goto upper pane/split" },
		{ "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "goto right pane/split" },
		{ "<C-Left>", resize("left"), desc = "resize pane/split left" },
		{ "<C-Down>", resize("down"), desc = "resize pane/split down" },
		{ "<C-Up>", resize("up"), desc = "resize pane/split up" },
		{ "<C-Right>", resize("right"), desc = "resize pane/split right" },
	},
}
