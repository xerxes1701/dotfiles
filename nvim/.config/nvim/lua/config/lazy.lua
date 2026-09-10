-- https://github.com/LazyVim/LazyVim
-- Bootstrap lazy.nvim

-- lazy.nvim manages itself through the spec below. The same SHA pins the
-- bootstrap clone, so a fresh install never runs an unreviewed commit.
-- Update it with the procedure in CLAUDE.md, like any other plugin.
local lazy_commit = "85c7ff3711b730b4030d03144f6db6375044ae82" -- v11.17.5

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", lazyrepo, lazypath })
  if vim.v.shell_error == 0 then
    out = vim.fn.system({ "git", "-C", lazypath, "checkout", "--quiet", lazy_commit })
  end
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    { "folke/lazy.nvim", commit = lazy_commit },
    -- import your plugins
    { 
       import = "plugins"
    },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true, notify = false },
  change_detection = { notify = false },
})
