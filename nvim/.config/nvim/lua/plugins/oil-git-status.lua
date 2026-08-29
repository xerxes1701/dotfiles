-- Git status (index / working-tree / merge-conflict) columns for oil.nvim.
-- https://github.com/refractalize/oil-git-status.nvim
--
-- Adds two sign columns to oil listings: the left is the git *index* status
-- (staged / uncommitted), the right is the *working-tree* status (unstaged);
-- unmerged/conflict states render as `U` (OilGitStatus*Unmerged highlights).
-- Status is fetched asynchronously so it never slows oil down on big repos.
--
-- Note: requires `signcolumn = "yes:3"` in oil's win_options (see oil.lua) so
-- these two columns plus our hand-rolled "unsaved buffer" marker all fit.
--
-- No tagged releases exist and the only branch is `main`, so this is pinned to
-- the newest `main` commit.

return {
	"refractalize/oil-git-status.nvim",
	dependencies = { "stevearc/oil.nvim" },
	commit = "a3e2ccb00cb8822115e28a9a1791eda051d940c9",
	config = true,
}
