-- On WSL, the git in ~/.local/lib/wsl-git (scripts package) goes first on
-- Neovim's PATH, so gitsigns, oil-git-status and the status line's git band
-- read a repository on a Windows drive with Windows' git.exe, which reads
-- NTFS fast; every other repository still gets Linux's git.
local wsl_git = vim.fs.joinpath(vim.env.HOME or "", ".local/lib/wsl-git")
if vim.env.WSL_DISTRO_NAME and vim.fn.executable(wsl_git .. "/git") == 1 then
	vim.env.PATH = wsl_git .. ":" .. vim.env.PATH
end

require("defaults")
require("keymap_registry").setup()
require("config.lazy")
require("keymaps")
