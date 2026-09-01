# Neovim Keybindings

_Generated from `keybindings.yaml` by `keybindings-to-md.cs`._

| Setting | Value |
| --- | --- |
| leader | `<Space>` |
| localleader | `\` |
| config_root | `.config/nvim` |

> **Legend**
> 🔸 marks an **implicitly-defined** keybinding — one a plugin sets by
> default (out-of-the-box), not something written in this configuration.
>
> 🔹 marks a **Neovim built-in** default — a core editor command that is
> not defined via a keymap (it never appears in `:map`/`nvim_get_keymap`).
>
> Totals: **520** keybindings — **233** explicit, **146** implicit defaults (🔸), **141** built-ins (🔹).

## Table of Contents

1. [Grouped by File](#sec-by-file)
   - [lua/config/hydra-codenav.lua](#file-luaconfighydra-codenavlua)
   - [lua/config/hydra-diagnostics.lua](#file-luaconfighydra-diagnosticslua)
   - [lua/keymaps.lua](#file-luakeymapslua)
   - [lua/plugins/blinkcmp.lua](#file-luapluginsblinkcmplua)
   - [lua/plugins/dap_ui.lua](#file-luapluginsdap-uilua)
   - [lua/plugins/difft.lua](#file-luapluginsdifftlua)
   - [lua/plugins/diffview.lua](#file-luapluginsdiffviewlua)
   - [lua/plugins/flash.lua](#file-luapluginsflashlua)
   - [lua/plugins/formatter.lua](#file-luapluginsformatterlua)
   - [lua/plugins/gitsigns.lua](#file-luapluginsgitsignslua)
   - [lua/plugins/harpoon.lua](#file-luapluginsharpoonlua)
   - [lua/plugins/history-traverse.lua](#file-luapluginshistory-traverselua)
   - [lua/plugins/linter.lua](#file-luapluginslinterlua)
   - [lua/plugins/lsp-saga.lua](#file-luapluginslsp-sagalua)
   - [lua/plugins/lspconfig.lua](#file-luapluginslspconfiglua)
   - [lua/plugins/maximizer.lua](#file-luapluginsmaximizerlua)
   - [lua/plugins/neogit.lua](#file-luapluginsneogitlua)
   - [lua/plugins/oil.lua](#file-luapluginsoillua)
   - [lua/plugins/snacks.nvim.lua](#file-luapluginssnacksnvimlua)
   - [lua/plugins/telescope.lua](#file-luapluginstelescopelua)
   - [lua/plugins/telescope_undo.lua](#file-luapluginstelescope-undolua)
   - [lua/plugins/tmux-naivation.lua](#file-luapluginstmux-naivationlua)
   - [lua/plugins/treesitter.lua](#file-luapluginstreesitterlua)
   - [lua/plugins/trouble.lua](#file-luapluginstroublelua)
   - [lua/plugins/whichkey.lua](#file-luapluginswhichkeylua)
2. [Grouped by Plugin](#sec-by-plugin)
   - [blink.cmp](#plugin-blinkcmp)
   - [codecompanion.nvim](#plugin-codecompanionnvim)
   - [Comment.nvim](#plugin-commentnvim)
   - [conform.nvim](#plugin-conformnvim)
   - [copilot.lua](#plugin-copilotlua)
   - [difft.nvim](#plugin-difftnvim)
   - [diffview.nvim](#plugin-diffviewnvim)
   - [flash.nvim](#plugin-flashnvim)
   - [gitsigns.nvim](#plugin-gitsignsnvim)
   - [harpoon](#plugin-harpoon)
   - [history-traverse](#plugin-history-traverse)
   - [hydra.nvim](#plugin-hydranvim)
   - [lspsaga.nvim](#plugin-lspsaganvim)
   - [mini.ai](#plugin-miniai)
   - [mini.operators](#plugin-minioperators)
   - [mini.splitjoin](#plugin-minisplitjoin)
   - [neogit](#plugin-neogit)
   - [nvim-dap-ui](#plugin-nvim-dap-ui)
   - [nvim-lint](#plugin-nvim-lint)
   - [nvim-lspconfig](#plugin-nvim-lspconfig)
   - [nvim-origami](#plugin-nvim-origami)
   - [nvim-surround](#plugin-nvim-surround)
   - [nvim-treesitter](#plugin-nvim-treesitter)
   - [oil.nvim](#plugin-oilnvim)
   - [snacks.nvim](#plugin-snacksnvim)
   - [telescope-undo.nvim](#plugin-telescope-undonvim)
   - [telescope.nvim](#plugin-telescopenvim)
   - [trouble.nvim](#plugin-troublenvim)
   - [vim-maximizer](#plugin-vim-maximizer)
   - [vim-tmux-navigator](#plugin-vim-tmux-navigator)
   - [which-key.nvim](#plugin-which-keynvim)
3. [Grouped Logically](#sec-logical)
   - [AI Chat](#group-ai-chat)
   - [Clipboard](#group-clipboard)
   - [Command](#group-command)
   - [Comments](#group-comments)
   - [Completion](#group-completion)
   - [Copilot](#group-copilot)
   - [Debug](#group-debug)
   - [Diagnostics](#group-diagnostics)
   - [Diagnostics Hydra](#group-diagnostics-hydra)
   - [Editing](#group-editing)
   - [File Explorer](#group-file-explorer)
   - [Folding](#group-folding)
   - [Folds](#group-folds)
   - [Fuzzy Find](#group-fuzzy-find)
   - [Git](#group-git)
   - [Harpoon](#group-harpoon)
   - [Help](#group-help)
   - [Insert](#group-insert)
   - [LSP](#group-lsp)
   - [Marks & Jumps](#group-marks--jumps)
   - [Misc](#group-misc)
   - [Motion](#group-motion)
   - [Navigation](#group-navigation)
   - [Operators](#group-operators)
   - [Registers & Macros](#group-registers--macros)
   - [Scrolling](#group-scrolling)
   - [Search](#group-search)
   - [Surround](#group-surround)
   - [Tabs](#group-tabs)
   - [Terminal](#group-terminal)
   - [Text Objects](#group-text-objects)
   - [Treewalker Hydra](#group-treewalker-hydra)
   - [Visual](#group-visual)
   - [Windows](#group-windows)
4. [All Keybindings (sorted)](#sec-all)

## Grouped by File <a id="sec-by-file"></a>

Every keybinding explicitly defined in the configuration, grouped by the
file it lives in. (Implicit plugin defaults have no source file and appear
in the plugin and logical views instead.)

### lua/config/hydra-codenav.lua <a id="file-luaconfighydra-codenavlua"></a>

Configures: `hydra.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `++` | hydra(treewalker) | Previous assignment (outer) (alias of =+)                                        | `goto_previous_start @assignment.outer`  |  |
| `+L` | hydra(treewalker) | Previous assignment (lhs) (alias of =L)                                          | `goto_previous_start @assignment.lhs`    |  |
| `+R` | hydra(treewalker) | Previous assignment (rhs) (alias of =R)                                          | `goto_previous_start @assignment.rhs`    |  |
| `=+` | hydra(treewalker) | Previous assignment (outer)                                                      | `goto_previous_start @assignment.outer`  |  |
| `==` | hydra(treewalker) | Next assignment (outer)                                                          | `goto_next_start @assignment.outer`      |  |
| `=l` | hydra(treewalker) | Next assignment (lhs)                                                            | `goto_next_start @assignment.lhs`        |  |
| `=L` | hydra(treewalker) | Previous assignment (lhs)                                                        | `goto_previous_start @assignment.lhs`    |  |
| `=r` | hydra(treewalker) | Next assignment (rhs)                                                            | `goto_next_start @assignment.rhs`        |  |
| `=R` | hydra(treewalker) | Previous assignment (rhs)                                                        | `goto_previous_start @assignment.rhs`    |  |
| `a` | hydra(treewalker) | Next parameter (outer)                                                           | `goto_next_start @parameter.outer`       |  |
| `A` | hydra(treewalker) | Previous parameter (outer)                                                       | `goto_previous_start @parameter.outer`   |  |
| `b` | hydra(treewalker) | Next block (outer)                                                               | `goto_next_start @block.outer`           |  |
| `B` | hydra(treewalker) | Previous block (outer)                                                           | `goto_previous_start @block.outer`       |  |
| `c` | hydra(treewalker) | Next comment (outer)                                                             | `goto_next_start @comment.outer`         |  |
| `C` | hydra(treewalker) | Previous comment (outer)                                                         | `goto_previous_start @comment.outer`     |  |
| `f` | hydra(treewalker) | Next call (outer)                                                                | `goto_next_start @call.outer`            |  |
| `F` | hydra(treewalker) | Previous call (outer)                                                            | `goto_previous_start @call.outer`        |  |
| `h` | hydra(treewalker) | Move left / ascend                                                               | `<cmd>Treewalker Left<cr>`               |  |
| `i` | hydra(treewalker) | Next conditional (outer)                                                         | `goto_next_start @conditional.outer`     |  |
| `I` | hydra(treewalker) | Previous conditional (outer)                                                     | `goto_previous_start @conditional.outer` |  |
| `j` | hydra(treewalker) | Move down a sibling node                                                         | `<cmd>Treewalker Down<cr>`               |  |
| `k` | hydra(treewalker) | Move up a sibling node                                                           | `<cmd>Treewalker Up<cr>`                 |  |
| `l` | hydra(treewalker) | Move right / descend                                                             | `<cmd>Treewalker Right<cr>`              |  |
| `m` | hydra(treewalker) | Next function (outer)                                                            | `goto_next_start @function.outer`        |  |
| `M` | hydra(treewalker) | Previous function (outer)                                                        | `goto_previous_start @function.outer`    |  |
| `n` | hydra(treewalker) | Next number (inner)                                                              | `goto_next_start @number.inner`          |  |
| `N` | hydra(treewalker) | Previous number (inner)                                                          | `goto_previous_start @number.inner`      |  |
| `o` | hydra(treewalker) | Next conditional (inner)                                                         | `goto_next_start @conditional.inner`     |  |
| `O` | hydra(treewalker) | Previous conditional (inner)                                                     | `goto_previous_start @conditional.inner` |  |
| `p` | hydra(treewalker) | Next parameter (inner)                                                           | `goto_next_start @parameter.inner`       |  |
| `P` | hydra(treewalker) | Previous parameter (inner)                                                       | `goto_previous_start @parameter.inner`   |  |
| `r` | hydra(treewalker) | Next return (outer)                                                              | `goto_next_start @return.outer`          |  |
| `R` | hydra(treewalker) | Previous return (outer)                                                          | `goto_previous_start @return.outer`      |  |
| `S` | n → hydra(treewalker) | Enter the pink hydra "treewalker" (also unbinds the default S)                   | `enter hydra`                            |  |
| `t` | hydra(treewalker) | Next class (outer)                                                               | `goto_next_start @class.outer`           |  |
| `T` | hydra(treewalker) | Previous class (outer)                                                           | `goto_previous_start @class.outer`       |  |
| `v` | hydra(treewalker) | Next block (outer)                                                               | `goto_next_start @block.outer`           |  |
| `V` | hydra(treewalker) | Previous block (inner)                                                           | `goto_previous_start @block.inner`       |  |
| `w` | hydra(treewalker) | Next loop (outer)                                                                | `goto_next_start @loop.outer`            |  |
| `W` | hydra(treewalker) | Previous loop (outer)                                                            | `goto_previous_start @loop.outer`        |  |

### lua/config/hydra-diagnostics.lua <a id="file-luaconfighydra-diagnosticslua"></a>

Configures: `hydra.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<Esc>` | hydra(diagnostics) | Leave the hydra                                                                  | `exit hydra`                             |  |
| `<leader>ld` | n → hydra(diagnostics) | Enter the red hydra "diagnostics"                                                | `enter hydra`                            |  |
| `b` | hydra(diagnostics) | Toggle scope (buffer/project)                                                    | `toggle scope buffer/project`            |  |
| `d` | hydra(diagnostics) | Next diagnostic                                                                  | `goto next diagnostic`                   |  |
| `D` | hydra(diagnostics) | Previous diagnostic                                                              | `goto previous diagnostic`               |  |
| `e` | hydra(diagnostics) | Next error                                                                       | `goto next ERROR diagnostic`             |  |
| `E` | hydra(diagnostics) | Previous error                                                                   | `goto previous ERROR diagnostic`         |  |
| `h` | hydra(diagnostics) | Next hint                                                                        | `goto next HINT diagnostic`              |  |
| `H` | hydra(diagnostics) | Previous hint                                                                    | `goto previous HINT diagnostic`          |  |
| `i` | hydra(diagnostics) | Next info                                                                        | `goto next INFO diagnostic`              |  |
| `I` | hydra(diagnostics) | Previous info                                                                    | `goto previous INFO diagnostic`          |  |
| `q` | hydra(diagnostics) | Leave the hydra                                                                  | `exit hydra`                             |  |
| `tc` | hydra(diagnostics) | Toggle CodeLenses                                                                | `toggle codelens_enabled`                |  |
| `ti` | hydra(diagnostics) | Toggle inlay hints                                                               | `toggle inlay hints`                     |  |
| `tv` | hydra(diagnostics) | Toggle virtual_lines                                                             | `toggle diagnostic virtual_lines`        |  |
| `w` | hydra(diagnostics) | Next warning                                                                     | `goto next WARN diagnostic`              |  |
| `W` | hydra(diagnostics) | Previous warning                                                                 | `goto previous WARN diagnostic`          |  |
| `x` | hydra(diagnostics) | Trouble diagnostics (workspace)                                                  | `<cmd>Trouble diagnostics toggle<cr>`    |  |
| `X` | hydra(diagnostics) | Trouble diagnostics (buffer)                                                     | `<cmd>Trouble diagnostics toggle filter.…` |  |
| `{` | hydra(diagnostics) | First diagnostic                                                                 | `goto first diagnostic`                  |  |
| `}` | hydra(diagnostics) | Last diagnostic                                                                  | `goto last diagnostic`                   |  |

### lua/keymaps.lua <a id="file-luakeymapslua"></a>

Core configuration (no plugin)

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<` | v | Indent left, keep selection                                                      | `<gv`                                    |  |
| `<` | n | Indent line left                                                                 | `<<`                                     |  |
| `<C-Down>` | n | Decrease split height                                                            | `:resize -1<CR>`                         |  |
| `<C-Left>` | n | Increase vertical split width                                                    | `:vertical resize +1<CR>`                |  |
| `<C-Right>` | n | Decrease vertical split width                                                    | `:vertical resize -1<CR>`                |  |
| `<C-Up>` | n | Increase split height                                                            | `:resize +1<CR>`                         |  |
| `<ESC>` | n | Clear search highlight                                                           | `:nohlsearch\|:echo<CR>`                 |  |
| `<Esc>` | t | Exit terminal insert mode                                                        | `<C-\><C-N>`                             |  |
| `<leader>+` | n | Increment number under cursor                                                    | `<C-a>`                                  |  |
| `<leader>-` | n | Decrement number under cursor                                                    | `<C-x>`                                  |  |
| `<leader><S-Tab>` | n | Go to previous tab                                                               | `<cmd>tabp<CR>`                          |  |
| `<leader><Tab>` | n | Go to next tab                                                                   | `<cmd>tabn<CR>`                          |  |
| `<leader>c` | n | Change (yank into default register)                                              | `c`                                      |  |
| `<leader>d` | n | Delete (yank into default register)                                              | `d`                                      |  |
| `<leader>L` | n | Open Lazy plugin manager                                                         | `<cmd>Lazy<CR>`                          |  |
| `<leader>p` | n | Paste from system clipboard                                                      | `"+p`                                    |  |
| `<leader>p` | v | Paste over selection without yanking                                             | `"_dP`                                   |  |
| `<leader>se` | n | Equalize split sizes                                                             | `<C-w>=`                                 |  |
| `<leader>sh` | n | Split window horizontally                                                        | `<cmd>split<CR>`                         |  |
| `<leader>sq` | n | Close current split                                                              | `<cmd>close<CR>`                         |  |
| `<leader>sv` | n | Split window vertically                                                          | `<cmd>vsplit<CR>`                        |  |
| `<leader>tf` | n | Open current file in new tab                                                     | `<cmd>tabnew %<CR>`                      |  |
| `<leader>tn` | n | Go to next tab                                                                   | `<cmd>tabn<CR>`                          |  |
| `<leader>to` | n | Open new tab                                                                     | `<cmd>tabnew<CR>`                        |  |
| `<leader>tp` | n | Go to previous tab                                                               | `<cmd>tabp<CR>`                          |  |
| `<leader>tq` | n | Close current tab                                                                | `<cmd>tabclose<CR>`                      |  |
| `<leader>y` | n | Yank to system clipboard                                                         | `"+y`                                    |  |
| `<leader>y` | v | Yank selection to system clipboard                                               | `"+y`                                    |  |
| `>` | v | Indent right, keep selection                                                     | `>gv`                                    |  |
| `>` | n | Indent line right                                                                | `>>`                                     |  |
| `c` | n | Change into black-hole register                                                  | `"_c`                                    |  |
| `d` | n | Delete into black-hole register                                                  | `"_d`                                    |  |
| `J` | x | Move selected block down                                                         | `:move '>+1<CR>gv=gv`                    |  |
| `K` | x | Move selected block up                                                           | `:move '<-2<CR>gv=gv`                    |  |
| `Q` | n | Disable Ex mode                                                                  | `<nop>`                                  |  |
| `x` | n | Delete char without yanking                                                      | `"_x`                                    |  |

### lua/plugins/blinkcmp.lua <a id="file-luapluginsblinkcmplua"></a>

Configures: `blink.cmp`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-b>` | i | Completion: scroll documentation up                                              | `scroll_documentation_up / fallback`     |  |
| `<C-f>` | i | Completion: scroll documentation down                                            | `scroll_documentation_down / fallback`   |  |
| `<C-space>` | i | Completion: open menu or toggle docs                                             | `show / show_documentation / hide_docume…` |  |

### lua/plugins/dap_ui.lua <a id="file-luapluginsdap-uilua"></a>

Configures: `nvim-dap-ui`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<F3>b` | n | Debug: toggle breakpoint                                                         | `dap.toggle_breakpoint`                  |  |
| `<F3>bd` | n | Debug: clear all breakpoints                                                     | `dap.clear_breakpoints`                  |  |
| `<F3>C` | n | Debug: run to cursor                                                             | `dap.run_to_cursor`                      |  |
| `<F3>cc` | n | Debug: continue                                                                  | `dap.continue`                           |  |
| `<F3>e` | n | Debug: evaluate expression                                                       | `dapui.eval`                             |  |
| `<F3>j` | n | Debug: go down a stack frame                                                     | `dap.down`                               |  |
| `<F3>k` | n | Debug: go up a stack frame                                                       | `dap.up`                                 |  |
| `<F3>q` | n | Debug: stop session                                                              | `dap.terminate`                          |  |
| `<F3>r` | n | Debug: toggle REPL                                                               | `dap.repl.toggle`                        |  |
| `<F3>uf` | n | Debug: toggle floating UI element                                                | `dapui.float_element`                    |  |
| `<F3>uu` | n | Debug: toggle UI                                                                 | `dapui.toggle`                           |  |
| `<F5>` | n | Debug: continue                                                                  | `dap.continue`                           |  |
| `<F6>` | n | Debug: step out                                                                  | `dap.step_out`                           |  |
| `<F7>` | n | Debug: step over                                                                 | `dap.step_over`                          |  |
| `<F8>` | n | Debug: run to cursor                                                             | `dap.run_to_cursor`                      |  |
| `<F9>` | n | Debug: step into                                                                 | `dap.step_into`                          |  |

### lua/plugins/difft.lua <a id="file-luapluginsdifftlua"></a>

Configures: `difft.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>cD` | n | Toggle difftastic diff view                                                      | `toggle Difft diff`                      |  |

### lua/plugins/diffview.lua <a id="file-luapluginsdiffviewlua"></a>

Configures: `diffview.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>cd` | n | Open Diffview                                                                    | `:DiffviewOpen<cr>`                      |  |

### lua/plugins/flash.lua <a id="file-luapluginsflashlua"></a>

Configures: `flash.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<c-s>` | c | Toggle flash while searching                                                     | `require('flash').toggle()`              |  |
| `<F17>` | n,x,o | Flash jump                                                                       | `require('flash').jump()`                |  |
| `<F18>` | n,x,o | Flash treesitter                                                                 | `require('flash').treesitter()`          |  |
| `<k7>` | n,x,o | Flash jump                                                                       | `require('flash').jump()`                |  |
| `r` | o | Remote flash (operator pending)                                                  | `require('flash').remote()`              |  |
| `R` | o,x | Treesitter search                                                                | `require('flash').treesitter_search()`   |  |
| `s` | n | Flash jump                                                                       | `require('flash').jump()`                |  |

### lua/plugins/formatter.lua <a id="file-luapluginsformatterlua"></a>

Configures: `conform.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>cf` | n,v | Format file or range                                                             | `conform.format`                         |  |

### lua/plugins/gitsigns.lua <a id="file-luapluginsgitsignslua"></a>

Configures: `gitsigns.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>gd` | n | Gitsigns: diff this                                                              | `<cmd>Gitsigns diffthis<cr>`             |  |
| `<leader>gp` | n | Gitsigns: preview hunk                                                           | `<cmd>Gitsigns preview_hunk<cr>`         |  |
| `<leader>gs` | n | Gitsigns: stage hunk                                                             | `<cmd>Gitsigns stage_hunk<cr>`           |  |
| `<leader>gu` | n | Gitsigns: undo stage hunk                                                        | `<cmd>Gitsigns undo_stage_hunk<cr>`      |  |

### lua/plugins/harpoon.lua <a id="file-luapluginsharpoonlua"></a>

Configures: `harpoon`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<A-1>` | n | Harpoon: go to file 1                                                            | `harpoon.ui.nav_file(1)`                 |  |
| `<A-2>` | n | Harpoon: go to file 2                                                            | `harpoon.ui.nav_file(2)`                 |  |
| `<A-3>` | n | Harpoon: go to file 3                                                            | `harpoon.ui.nav_file(3)`                 |  |
| `<A-4>` | n | Harpoon: go to file 4                                                            | `harpoon.ui.nav_file(4)`                 |  |
| `<A-5>` | n | Harpoon: go to file 5                                                            | `harpoon.ui.nav_file(5)`                 |  |
| `<A-6>` | n | Harpoon: go to file 6                                                            | `harpoon.ui.nav_file(6)`                 |  |
| `<A-7>` | n | Harpoon: go to file 7                                                            | `harpoon.ui.nav_file(7)`                 |  |
| `<A-8>` | n | Harpoon: go to file 8                                                            | `harpoon.ui.nav_file(8)`                 |  |
| `<A-9>` | n | Harpoon: go to file 9                                                            | `harpoon.ui.nav_file(9)`                 |  |
| `<leader>ha` | n | Harpoon: add current file                                                        | `harpoon.mark.add_file`                  |  |
| `<leader>hh` | n | Harpoon: toggle quick menu                                                       | `harpoon.ui.toggle_quick_menu`           |  |

### lua/plugins/history-traverse.lua <a id="file-luapluginshistory-traverselua"></a>

Configures: `history-traverse`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `gj` | n | History: go back                                                                 | `<cmd>HisTravBack<cr>`                   |  |
| `gk` | n | History: go forward                                                              | `<cmd>HisTravForward<cr>`                |  |

### lua/plugins/linter.lua <a id="file-luapluginslinterlua"></a>

Configures: `nvim-lint`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>cl` | n | Trigger linting                                                                  | `lint.try_lint`                          |  |

### lua/plugins/lsp-saga.lua <a id="file-luapluginslsp-sagalua"></a>

Configures: `lspsaga.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-F14>` | n | Go to previous diagnostic                                                        | `:Lspsaga diagnostic_jump_prev<CR>`      |  |
| `<F14>` | n | Go to next diagnostic                                                            | `:Lspsaga diagnostic_jump_next<CR>`      |  |
| `<leader>la` | n | LSP: code action (Lspsaga)                                                       | `:Lspsaga code_action<CR>`               |  |

### lua/plugins/lspconfig.lua <a id="file-luapluginslspconfiglua"></a>

Configures: `nvim-lspconfig`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-s>` | i | LSP: signature help                                                              | `vim.lsp.buf.signature_help`             |  |
| `<leader>lc` | n | LSP: run CodeLens action                                                         | `vim.lsp.codelens.run`                   |  |
| `<leader>lr` | n | LSP: rename symbol                                                               | `vim.lsp.buf.rename`                     |  |
| `<leader>lSr` | n | LSP: restart                                                                     | `<cmd>lsp restart<CR>`                   |  |
| `gD` | n | LSP: go to declaration                                                           | `vim.lsp.buf.declaration`                |  |
| `gd` | n | LSP: definitions (Telescope)                                                     | `<cmd>Telescope lsp_definitions<CR>`     |  |
| `gi` | n | LSP: implementations (Telescope)                                                 | `<cmd>Telescope lsp_implementations<CR>` |  |
| `gR` | n | LSP: references (Telescope)                                                      | `<cmd>Telescope lsp_references<CR>`      |  |
| `gt` | n | LSP: type definitions (Telescope)                                                | `<cmd>Telescope lsp_type_implementations…` |  |
| `K` | n | LSP: hover documentation                                                         | `vim.lsp.buf.hover`                      |  |

### lua/plugins/maximizer.lua <a id="file-luapluginsmaximizerlua"></a>

Configures: `vim-maximizer`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>sm` | n | Toggle split maximize                                                            | `<cmd>MaximizerToggle<CR>`               |  |

### lua/plugins/neogit.lua <a id="file-luapluginsneogitlua"></a>

Configures: `neogit`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>gg` | n | Open Neogit                                                                      | `<cmd>Neogit<CR>`                        |  |

### lua/plugins/oil.lua <a id="file-luapluginsoillua"></a>

Configures: `oil.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `-` | n | Oil: go to parent directory                                                      | `actions.parent`                         |  |
| `<CR>` | n | Oil: open entry                                                                  | `actions.select`                         |  |
| `<leader>ed` | n | Oil: edit current file's directory                                               | `<cmd>edit %:p:h<CR>`                    |  |
| `<leader>eD` | n | Oil: edit current working directory                                              | `<cmd>edit .<CR>`                        |  |
| `g.` | n | Oil: toggle hidden files                                                         | `actions.toggle_hidden`                  |  |
| `g?` | n | Oil: show help                                                                   | `actions.show_help`                      |  |
| `gh` | n | Oil: open entry in horizontal split                                              | `actions.select horizontal`              |  |
| `gp` | n | Oil: preview entry                                                               | `actions.preview`                        |  |
| `gq` | n | Oil: close                                                                       | `actions.close`                          |  |
| `gr` | n | Oil: refresh                                                                     | `actions.refresh`                        |  |
| `gs` | n | Oil: change sort                                                                 | `actions.change_sort`                    |  |
| `gt` | n | Oil: open entry in new tab                                                       | `actions.select tab`                     |  |
| `gv` | n | Oil: open entry in vertical split                                                | `actions.select vertical`                |  |
| `gx` | n | Oil: open externally                                                             | `actions.open_external`                  |  |
| `g\` | n | Oil: toggle trash                                                                | `actions.toggle_trash`                   |  |
| `_` | n | Oil: open current working directory                                              | `actions.open_cwd`                       |  |
| `'` | n | Oil: :cd to directory                                                            | `actions.cd`                             |  |
| `~` | n | Oil: :tcd to directory                                                           | `actions.cd scope=tab`                   |  |

### lua/plugins/snacks.nvim.lua <a id="file-luapluginssnacksnvimlua"></a>

Configures: `snacks.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader><leader>sn` | n | Show notification history                                                        | `Snacks.notifier.show_history()`         |  |

### lua/plugins/telescope.lua <a id="file-luapluginstelescopelua"></a>

Configures: `telescope.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-j>` | i | Telescope picker: move to next item                                              | `actions.move_selection_next`            |  |
| `<C-k>` | i | Telescope picker: move to previous item                                          | `actions.move_selection_previous`        |  |
| `<C-q>` | i | Telescope picker: send selection to quickfix                                     | `send_selected_to_qflist + open_qflist`  |  |
| `<leader>f?` | n | Fuzzy find: help tags                                                            | `<cmd>Telescope help_tags<cr>`           |  |
| `<leader>fb` | n | Fuzzy find: buffers                                                              | `<cmd>Telescope buffers<cr>`             |  |
| `<leader>ff` | n | Fuzzy find: files                                                                | `<cmd>Telescope find_files<cr>`          |  |
| `<leader>fF` | n | Fuzzy find: hidden files                                                         | `<cmd>Telescope find_files hidden=true<c…` |  |
| `<leader>fg` | n | Fuzzy find: live grep                                                            | `<cmd>Telescope live_grep<cr>`           |  |
| `<leader>fh` | n | Fuzzy find: harpoon marks                                                        | `<cmd>Telescope harpoon marks<CR>`       |  |
| `<leader>fj` | n | Fuzzy find: jumplist entries                                                     | `<cmd>Telescope jumplist<CR>`            |  |
| `<leader>fk` | n | Fuzzy find: keymaps                                                              | `<cmd>Telescope keymaps<cr>`             |  |
| `<leader>fK` | n | Fuzzy find: keymaps by plugin                                                    | `<cmd>lua require('keymap_registry').pic…` |  |
| `<leader>fr` | n | Fuzzy find: recent files                                                         | `<cmd>Telescope oldfiles<cr>`            |  |
| `<leader>ft` | n | Fuzzy find: TODO comments                                                        | `<cmd>TodoTelescope<CR>`                 |  |

### lua/plugins/telescope_undo.lua <a id="file-luapluginstelescope-undolua"></a>

Configures: `telescope-undo.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>u` | n | Browse undo history                                                              | `<cmd>Telescope undo<cr>`                |  |

### lua/plugins/tmux-naivation.lua <a id="file-luapluginstmux-naivationlua"></a>

Configures: `vim-tmux-navigator`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<c-h>` | n | Navigate to left pane/split                                                      | `<cmd>TmuxNavigateLeft<cr>`              |  |
| `<c-j>` | n | Navigate to lower pane/split                                                     | `<cmd>TmuxNavigateDown<cr>`              |  |
| `<c-k>` | n | Navigate to upper pane/split                                                     | `<cmd>TmuxNavigateUp<cr>`                |  |
| `<c-l>` | n | Navigate to right pane/split                                                     | `<cmd>TmuxNavigateRight<cr>`             |  |
| `<c-\>` | n | Navigate to previous pane/split                                                  | `<cmd>TmuxNavigatePrevious<cr>`          |  |

### lua/plugins/treesitter.lua <a id="file-luapluginstreesitterlua"></a>

Configures: `nvim-treesitter`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<A-v>` | n | Incremental selection: start / expand node                                       | `init_selection`                         |  |
| `<A-v>` | x | Incremental selection: expand to next node                                       | `node_incremental`                       |  |
| `<A-V>` | x | Incremental selection: shrink node                                               | `node_decremental`                       |  |
| `<end>` | n,x,o | Repeat last textobject move forward                                              | `repeat_last_move (forward)`             |  |
| `<home>` | n,x,o | Repeat last textobject move backward                                             | `repeat_last_move (backward)`            |  |
| `<leader>a` | n | Swap parameter with next                                                         | `swap_next @parameter.inner`             |  |
| `<leader>A` | n | Swap parameter with previous                                                     | `swap_previous @parameter.inner`         |  |
| `==` | x,o | Textobject: assignment (outer)                                                   | `@assignment.outer`                      |  |
| `=l` | x,o | Textobject: assignment left-hand side                                            | `@assignment.lhs`                        |  |
| `=r` | x,o | Textobject: assignment right-hand side                                           | `@assignment.rhs`                        |  |
| `aa` | x,o | Textobject: parameter (outer)                                                    | `@parameter.outer`                       |  |
| `ab` | x,o | Textobject: block (outer)                                                        | `@block.outer`                           |  |
| `ac` | x,o | Textobject: comment (outer)                                                      | `@comment.outer`                         |  |
| `af` | x,o | Textobject: call (outer)                                                         | `@call.outer`                            |  |
| `ai` | x,o | Textobject: conditional (outer)                                                  | `@conditional.outer`                     |  |
| `al` | x,o | Textobject: loop (outer)                                                         | `@loop.outer`                            |  |
| `am` | x,o | Textobject: function (outer)                                                     | `@function.outer`                        |  |
| `an` | x,o | Textobject: number (inner)                                                       | `@number.inner`                          |  |
| `ar` | x,o | Textobject: return (outer)                                                       | `@return.outer`                          |  |
| `at` | x,o | Textobject: class (outer)                                                        | `@class.outer`                           |  |
| `ia` | x,o | Textobject: parameter (inner)                                                    | `@parameter.inner`                       |  |
| `ib` | x,o | Textobject: block (inner)                                                        | `@block.inner`                           |  |
| `ic` | x,o | Textobject: comment (outer)                                                      | `@comment.outer`                         |  |
| `if` | x,o | Textobject: call (inner)                                                         | `@call.inner`                            |  |
| `ii` | x,o | Textobject: conditional (inner)                                                  | `@conditional.inner`                     |  |
| `il` | x,o | Textobject: loop (inner)                                                         | `@loop.inner`                            |  |
| `im` | x,o | Textobject: function (inner)                                                     | `@function.inner`                        |  |
| `in` | x,o | Textobject: number (inner)                                                       | `@number.inner`                          |  |
| `ir` | x,o | Textobject: return (inner)                                                       | `@return.inner`                          |  |
| `it` | x,o | Textobject: class (inner)                                                        | `@class.inner`                           |  |

### lua/plugins/trouble.lua <a id="file-luapluginstroublelua"></a>

Configures: `trouble.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>lo` | n | Trouble: location list                                                           | `<cmd>Trouble loclist toggle<cr>`        |  |
| `<leader>lq` | n | Trouble: quickfix list                                                           | `<cmd>Trouble qflist toggle<cr>`         |  |
| `<leader>ls` | n | Trouble: document symbols                                                        | `<cmd>Trouble symbols toggle focus=false…` |  |
| `<leader>lSl` | n | Trouble: LSP definitions/references                                              | `<cmd>Trouble lsp toggle focus=false win…` |  |

### lua/plugins/whichkey.lua <a id="file-luapluginswhichkeylua"></a>

Configures: `which-key.nvim`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>?` | n | Show all keymaps (which-key)                                                     | `require('which-key').show({ global = tr…` |  |

## Grouped by Plugin <a id="sec-by-plugin"></a>

Keybindings associated with a plugin — both those defined in the plugin's
config file and the plugin's implicit defaults (🔸). Core-config
keybindings that belong to no plugin are omitted here.

### blink.cmp <a id="plugin-blinkcmp"></a>

Defined in: `lua/plugins/blinkcmp.lua`; includes 12 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-b>` | i | Completion: scroll documentation up                                              | `scroll_documentation_up / fallback`     |  |
| `<C-f>` | i | Completion: scroll documentation down                                            | `scroll_documentation_down / fallback`   |  |
| `<C-space>` | i | Completion: open menu or toggle docs                                             | `show / show_documentation / hide_docume…` |  |
| `<C-b>` | i | Completion: scroll documentation up                                              | `scroll docs up`                         | 🔸 |
| `<C-e>` | i | Completion: cancel / hide menu                                                   | `hide menu`                              | 🔸 |
| `<C-f>` | i | Completion: scroll documentation down                                            | `scroll docs down`                       | 🔸 |
| `<C-k>` | i | Completion: toggle signature help                                                | `toggle signature help`                  | 🔸 |
| `<C-n>` | i | Completion: select next item                                                     | `select next`                            | 🔸 |
| `<C-p>` | i | Completion: select previous item                                                 | `select previous`                        | 🔸 |
| `<C-space>` | i | Completion: open menu or toggle docs                                             | `show menu / toggle docs`                | 🔸 |
| `<C-y>` | i | Completion: accept selected item                                                 | `accept item`                            | 🔸 |
| `<Down>` | i | Completion: select next item                                                     | `select next`                            | 🔸 |
| `<S-Tab>` | i | Completion: jump to previous snippet placeholder                                 | `prev snippet placeholder`               | 🔸 |
| `<Tab>` | i | Completion: jump to next snippet placeholder                                     | `next snippet placeholder`               | 🔸 |
| `<Up>` | i | Completion: select previous item                                                 | `select previous`                        | 🔸 |

### codecompanion.nvim <a id="plugin-codecompanionnvim"></a>

includes 18 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-c>` | n,i | CodeCompanion chat: close buffer                                                 | `chat: close`                            | 🔸 |
| `<C-s>` | n,i | CodeCompanion chat: send message                                                 | `chat: send`                             | 🔸 |
| `<C-_>` | i | CodeCompanion chat: open completion menu                                         | `chat: completion menu`                  | 🔸 |
| `<CR>` | n | CodeCompanion chat: send message                                                 | `chat: send`                             | 🔸 |
| `?` | n | CodeCompanion chat: show keymap help                                             | `chat: options/help`                     | 🔸 |
| `ga` | n | CodeCompanion chat: change adapter/model                                         | `chat: change adapter`                   | 🔸 |
| `gc` | n | CodeCompanion chat: insert empty codeblock                                       | `chat: insert codeblock`                 | 🔸 |
| `gd` | n | CodeCompanion chat: show debug info                                              | `chat: debug info`                       | 🔸 |
| `gf` | n | CodeCompanion chat: fold all codeblocks                                          | `chat: fold codeblocks`                  | 🔸 |
| `gr` | n | CodeCompanion chat: regenerate last response                                     | `chat: regenerate`                       | 🔸 |
| `gs` | n | CodeCompanion chat: toggle system prompt                                         | `chat: toggle system prompt`             | 🔸 |
| `gx` | n | CodeCompanion chat: clear all messages                                           | `chat: clear`                            | 🔸 |
| `gy` | n | CodeCompanion chat: yank last codeblock                                          | `chat: yank codeblock`                   | 🔸 |
| `q` | n | CodeCompanion chat: stop current request                                         | `chat: stop request`                     | 🔸 |
| `[[` | n | CodeCompanion chat: jump to previous message header                              | `chat: previous header`                  | 🔸 |
| `]]` | n | CodeCompanion chat: jump to next message header                                  | `chat: next header`                      | 🔸 |
| `{` | n | CodeCompanion chat: open previous chat                                           | `chat: previous chat`                    | 🔸 |
| `}` | n | CodeCompanion chat: open next chat                                               | `chat: next chat`                        | 🔸 |

### Comment.nvim <a id="plugin-commentnvim"></a>

includes 9 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `gb` | x | Comment: toggle selection (blockwise)                                            | `toggle blockwise comment (selection)`   | 🔸 |
| `gbc` | n | Comment: toggle current line (blockwise)                                         | `toggle blockwise comment (line)`        | 🔸 |
| `gb{motion}` | n | Comment: blockwise comment over a motion                                         | `toggle blockwise comment (operator)`    | 🔸 |
| `gc` | x | Comment: toggle selection (linewise)                                             | `toggle linewise comment (selection)`    | 🔸 |
| `gcA` | n | Comment: append comment at end of line                                           | `comment end of line + insert`           | 🔸 |
| `gcc` | n | Comment: toggle current line (linewise)                                          | `toggle linewise comment (line)`         | 🔸 |
| `gco` | n | Comment: add comment on line below                                               | `comment line below + insert`            | 🔸 |
| `gcO` | n | Comment: add comment on line above                                               | `comment line above + insert`            | 🔸 |
| `gc{motion}` | n | Comment: linewise comment over a motion                                          | `toggle linewise comment (operator)`     | 🔸 |

### conform.nvim <a id="plugin-conformnvim"></a>

Defined in: `lua/plugins/formatter.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>cf` | n,v | Format file or range                                                             | `conform.format`                         |  |

### copilot.lua <a id="plugin-copilotlua"></a>

includes 9 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-]>` | i | Copilot: dismiss current suggestion                                              | `dismiss suggestion`                     | 🔸 |
| `<CR>` | n | Copilot panel: accept suggestion under cursor                                    | `panel: accept`                          | 🔸 |
| `<M-CR>` | n | Copilot: open suggestion panel                                                   | `open panel`                             | 🔸 |
| `<M-l>` | i | Copilot: accept inline suggestion                                                | `accept suggestion`                      | 🔸 |
| `<M-[>` | i | Copilot: show previous suggestion                                                | `prev suggestion`                        | 🔸 |
| `<M-]>` | i | Copilot: show next suggestion                                                    | `next suggestion`                        | 🔸 |
| `gr` | n | Copilot panel: refresh suggestions                                               | `panel: refresh`                         | 🔸 |
| `[[` | n | Copilot panel: jump to previous suggestion                                       | `panel: prev suggestion`                 | 🔸 |
| `]]` | n | Copilot panel: jump to next suggestion                                           | `panel: next suggestion`                 | 🔸 |

### difft.nvim <a id="plugin-difftnvim"></a>

Defined in: `lua/plugins/difft.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>cD` | n | Toggle difftastic diff view                                                      | `toggle Difft diff`                      |  |

### diffview.nvim <a id="plugin-diffviewnvim"></a>

Defined in: `lua/plugins/diffview.lua`; includes 14 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>cd` | n | Open Diffview                                                                    | `:DiffviewOpen<cr>`                      |  |
| `-` | n | Diffview file panel: stage/unstage entry                                         | `stage/unstage entry (file panel)`       | 🔸 |
| `<leader>b` | n | Diffview: toggle the file panel                                                  | `toggle file panel`                      | 🔸 |
| `<leader>cb` | n | Diffview merge: choose BASE                                                      | `conflict: choose base`                  | 🔸 |
| `<leader>co` | n | Diffview merge: choose OURS                                                      | `conflict: choose ours`                  | 🔸 |
| `<leader>ct` | n | Diffview merge: choose THEIRS                                                    | `conflict: choose theirs`                | 🔸 |
| `<leader>e` | n | Diffview: focus the file panel                                                   | `focus file panel`                       | 🔸 |
| `<S-Tab>` | n | Diffview: open diff for previous file                                            | `previous file diff`                     | 🔸 |
| `<Tab>` | n | Diffview: open diff for next file                                                | `next file diff`                         | 🔸 |
| `gf` | n | Diffview: open local file in a tabpage                                           | `goto_file`                              | 🔸 |
| `S` | n | Diffview file panel: stage all entries                                           | `stage all (file panel)`                 | 🔸 |
| `U` | n | Diffview file panel: unstage all entries                                         | `unstage all (file panel)`               | 🔸 |
| `X` | n | Diffview file panel: revert file to left state                                   | `restore entry (file panel)`             | 🔸 |
| `[x` | n | Diffview merge: jump to previous conflict                                        | `previous conflict`                      | 🔸 |
| `]x` | n | Diffview merge: jump to next conflict                                            | `next conflict`                          | 🔸 |

### flash.nvim <a id="plugin-flashnvim"></a>

Defined in: `lua/plugins/flash.lua`; includes 6 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<c-s>` | c | Toggle flash while searching                                                     | `require('flash').toggle()`              |  |
| `<F17>` | n,x,o | Flash jump                                                                       | `require('flash').jump()`                |  |
| `<F18>` | n,x,o | Flash treesitter                                                                 | `require('flash').treesitter()`          |  |
| `<k7>` | n,x,o | Flash jump                                                                       | `require('flash').jump()`                |  |
| `r` | o | Remote flash (operator pending)                                                  | `require('flash').remote()`              |  |
| `R` | o,x | Treesitter search                                                                | `require('flash').treesitter_search()`   |  |
| `s` | n | Flash jump                                                                       | `require('flash').jump()`                |  |
| `,` | n,x,o | Flash: repeat last char motion, opposite direction                               | `repeat f/t/F/T (opposite dir)`          | 🔸 |
| `;` | n,x,o | Flash: repeat last char motion, same direction                                   | `repeat f/t/F/T (same dir)`              | 🔸 |
| `f` | n,x,o | Flash: enhanced f, jump to char (dot-repeat)                                     | `enhanced f (flash char)`                | 🔸 |
| `F` | n,x,o | Flash: enhanced F, backward jump to char                                         | `enhanced F (flash char back)`           | 🔸 |
| `t` | n,x,o | Flash: enhanced t, jump till char                                                | `enhanced t (flash till)`                | 🔸 |
| `T` | n,x,o | Flash: enhanced T, backward jump till char                                       | `enhanced T (flash till back)`           | 🔸 |

### gitsigns.nvim <a id="plugin-gitsignsnvim"></a>

Defined in: `lua/plugins/gitsigns.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>gd` | n | Gitsigns: diff this                                                              | `<cmd>Gitsigns diffthis<cr>`             |  |
| `<leader>gp` | n | Gitsigns: preview hunk                                                           | `<cmd>Gitsigns preview_hunk<cr>`         |  |
| `<leader>gs` | n | Gitsigns: stage hunk                                                             | `<cmd>Gitsigns stage_hunk<cr>`           |  |
| `<leader>gu` | n | Gitsigns: undo stage hunk                                                        | `<cmd>Gitsigns undo_stage_hunk<cr>`      |  |

### harpoon <a id="plugin-harpoon"></a>

Defined in: `lua/plugins/harpoon.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<A-1>` | n | Harpoon: go to file 1                                                            | `harpoon.ui.nav_file(1)`                 |  |
| `<A-2>` | n | Harpoon: go to file 2                                                            | `harpoon.ui.nav_file(2)`                 |  |
| `<A-3>` | n | Harpoon: go to file 3                                                            | `harpoon.ui.nav_file(3)`                 |  |
| `<A-4>` | n | Harpoon: go to file 4                                                            | `harpoon.ui.nav_file(4)`                 |  |
| `<A-5>` | n | Harpoon: go to file 5                                                            | `harpoon.ui.nav_file(5)`                 |  |
| `<A-6>` | n | Harpoon: go to file 6                                                            | `harpoon.ui.nav_file(6)`                 |  |
| `<A-7>` | n | Harpoon: go to file 7                                                            | `harpoon.ui.nav_file(7)`                 |  |
| `<A-8>` | n | Harpoon: go to file 8                                                            | `harpoon.ui.nav_file(8)`                 |  |
| `<A-9>` | n | Harpoon: go to file 9                                                            | `harpoon.ui.nav_file(9)`                 |  |
| `<leader>ha` | n | Harpoon: add current file                                                        | `harpoon.mark.add_file`                  |  |
| `<leader>hh` | n | Harpoon: toggle quick menu                                                       | `harpoon.ui.toggle_quick_menu`           |  |

### history-traverse <a id="plugin-history-traverse"></a>

Defined in: `lua/plugins/history-traverse.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `gj` | n | History: go back                                                                 | `<cmd>HisTravBack<cr>`                   |  |
| `gk` | n | History: go forward                                                              | `<cmd>HisTravForward<cr>`                |  |

### hydra.nvim <a id="plugin-hydranvim"></a>

Defined in: `lua/config/hydra-codenav.lua`, `lua/config/hydra-diagnostics.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `++` | hydra(treewalker) | Previous assignment (outer) (alias of =+)                                        | `goto_previous_start @assignment.outer`  |  |
| `+L` | hydra(treewalker) | Previous assignment (lhs) (alias of =L)                                          | `goto_previous_start @assignment.lhs`    |  |
| `+R` | hydra(treewalker) | Previous assignment (rhs) (alias of =R)                                          | `goto_previous_start @assignment.rhs`    |  |
| `<Esc>` | hydra(diagnostics) | Leave the hydra                                                                  | `exit hydra`                             |  |
| `<leader>ld` | n → hydra(diagnostics) | Enter the red hydra "diagnostics"                                                | `enter hydra`                            |  |
| `=+` | hydra(treewalker) | Previous assignment (outer)                                                      | `goto_previous_start @assignment.outer`  |  |
| `==` | hydra(treewalker) | Next assignment (outer)                                                          | `goto_next_start @assignment.outer`      |  |
| `=l` | hydra(treewalker) | Next assignment (lhs)                                                            | `goto_next_start @assignment.lhs`        |  |
| `=L` | hydra(treewalker) | Previous assignment (lhs)                                                        | `goto_previous_start @assignment.lhs`    |  |
| `=r` | hydra(treewalker) | Next assignment (rhs)                                                            | `goto_next_start @assignment.rhs`        |  |
| `=R` | hydra(treewalker) | Previous assignment (rhs)                                                        | `goto_previous_start @assignment.rhs`    |  |
| `a` | hydra(treewalker) | Next parameter (outer)                                                           | `goto_next_start @parameter.outer`       |  |
| `A` | hydra(treewalker) | Previous parameter (outer)                                                       | `goto_previous_start @parameter.outer`   |  |
| `b` | hydra(treewalker) | Next block (outer)                                                               | `goto_next_start @block.outer`           |  |
| `B` | hydra(treewalker) | Previous block (outer)                                                           | `goto_previous_start @block.outer`       |  |
| `b` | hydra(diagnostics) | Toggle scope (buffer/project)                                                    | `toggle scope buffer/project`            |  |
| `c` | hydra(treewalker) | Next comment (outer)                                                             | `goto_next_start @comment.outer`         |  |
| `C` | hydra(treewalker) | Previous comment (outer)                                                         | `goto_previous_start @comment.outer`     |  |
| `d` | hydra(diagnostics) | Next diagnostic                                                                  | `goto next diagnostic`                   |  |
| `D` | hydra(diagnostics) | Previous diagnostic                                                              | `goto previous diagnostic`               |  |
| `e` | hydra(diagnostics) | Next error                                                                       | `goto next ERROR diagnostic`             |  |
| `E` | hydra(diagnostics) | Previous error                                                                   | `goto previous ERROR diagnostic`         |  |
| `f` | hydra(treewalker) | Next call (outer)                                                                | `goto_next_start @call.outer`            |  |
| `F` | hydra(treewalker) | Previous call (outer)                                                            | `goto_previous_start @call.outer`        |  |
| `h` | hydra(treewalker) | Move left / ascend                                                               | `<cmd>Treewalker Left<cr>`               |  |
| `h` | hydra(diagnostics) | Next hint                                                                        | `goto next HINT diagnostic`              |  |
| `H` | hydra(diagnostics) | Previous hint                                                                    | `goto previous HINT diagnostic`          |  |
| `i` | hydra(treewalker) | Next conditional (outer)                                                         | `goto_next_start @conditional.outer`     |  |
| `I` | hydra(treewalker) | Previous conditional (outer)                                                     | `goto_previous_start @conditional.outer` |  |
| `i` | hydra(diagnostics) | Next info                                                                        | `goto next INFO diagnostic`              |  |
| `I` | hydra(diagnostics) | Previous info                                                                    | `goto previous INFO diagnostic`          |  |
| `j` | hydra(treewalker) | Move down a sibling node                                                         | `<cmd>Treewalker Down<cr>`               |  |
| `k` | hydra(treewalker) | Move up a sibling node                                                           | `<cmd>Treewalker Up<cr>`                 |  |
| `l` | hydra(treewalker) | Move right / descend                                                             | `<cmd>Treewalker Right<cr>`              |  |
| `m` | hydra(treewalker) | Next function (outer)                                                            | `goto_next_start @function.outer`        |  |
| `M` | hydra(treewalker) | Previous function (outer)                                                        | `goto_previous_start @function.outer`    |  |
| `n` | hydra(treewalker) | Next number (inner)                                                              | `goto_next_start @number.inner`          |  |
| `N` | hydra(treewalker) | Previous number (inner)                                                          | `goto_previous_start @number.inner`      |  |
| `o` | hydra(treewalker) | Next conditional (inner)                                                         | `goto_next_start @conditional.inner`     |  |
| `O` | hydra(treewalker) | Previous conditional (inner)                                                     | `goto_previous_start @conditional.inner` |  |
| `p` | hydra(treewalker) | Next parameter (inner)                                                           | `goto_next_start @parameter.inner`       |  |
| `P` | hydra(treewalker) | Previous parameter (inner)                                                       | `goto_previous_start @parameter.inner`   |  |
| `q` | hydra(diagnostics) | Leave the hydra                                                                  | `exit hydra`                             |  |
| `r` | hydra(treewalker) | Next return (outer)                                                              | `goto_next_start @return.outer`          |  |
| `R` | hydra(treewalker) | Previous return (outer)                                                          | `goto_previous_start @return.outer`      |  |
| `S` | n → hydra(treewalker) | Enter the pink hydra "treewalker" (also unbinds the default S)                   | `enter hydra`                            |  |
| `t` | hydra(treewalker) | Next class (outer)                                                               | `goto_next_start @class.outer`           |  |
| `T` | hydra(treewalker) | Previous class (outer)                                                           | `goto_previous_start @class.outer`       |  |
| `tc` | hydra(diagnostics) | Toggle CodeLenses                                                                | `toggle codelens_enabled`                |  |
| `ti` | hydra(diagnostics) | Toggle inlay hints                                                               | `toggle inlay hints`                     |  |
| `tv` | hydra(diagnostics) | Toggle virtual_lines                                                             | `toggle diagnostic virtual_lines`        |  |
| `v` | hydra(treewalker) | Next block (outer)                                                               | `goto_next_start @block.outer`           |  |
| `V` | hydra(treewalker) | Previous block (inner)                                                           | `goto_previous_start @block.inner`       |  |
| `w` | hydra(treewalker) | Next loop (outer)                                                                | `goto_next_start @loop.outer`            |  |
| `W` | hydra(treewalker) | Previous loop (outer)                                                            | `goto_previous_start @loop.outer`        |  |
| `w` | hydra(diagnostics) | Next warning                                                                     | `goto next WARN diagnostic`              |  |
| `W` | hydra(diagnostics) | Previous warning                                                                 | `goto previous WARN diagnostic`          |  |
| `x` | hydra(diagnostics) | Trouble diagnostics (workspace)                                                  | `<cmd>Trouble diagnostics toggle<cr>`    |  |
| `X` | hydra(diagnostics) | Trouble diagnostics (buffer)                                                     | `<cmd>Trouble diagnostics toggle filter.…` |  |
| `{` | hydra(diagnostics) | First diagnostic                                                                 | `goto first diagnostic`                  |  |
| `}` | hydra(diagnostics) | Last diagnostic                                                                  | `goto last diagnostic`                   |  |

### lspsaga.nvim <a id="plugin-lspsaganvim"></a>

Defined in: `lua/plugins/lsp-saga.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-F14>` | n | Go to previous diagnostic                                                        | `:Lspsaga diagnostic_jump_prev<CR>`      |  |
| `<F14>` | n | Go to next diagnostic                                                            | `:Lspsaga diagnostic_jump_next<CR>`      |  |
| `<leader>la` | n | LSP: code action (Lspsaga)                                                       | `:Lspsaga code_action<CR>`               |  |

### mini.ai <a id="plugin-miniai"></a>

includes 4 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `a{id}` | x,o | mini.ai: select 'around' textobject {id}                                         | `select around textobject`               | 🔸 |
| `g[` | n,x,o | mini.ai: move to left edge of nearest textobject                                 | `go to left edge of textobject`          | 🔸 |
| `g]` | n,x,o | mini.ai: move to right edge of nearest textobject                                | `go to right edge of textobject`         | 🔸 |
| `i{id}` | x,o | mini.ai: select 'inside' textobject {id}                                         | `select inside textobject`               | 🔸 |

### mini.operators <a id="plugin-minioperators"></a>

includes 15 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `g=` | n | mini.operators: evaluate text and replace with result                            | `evaluate (motion)`                      | 🔸 |
| `g=` | x | mini.operators: evaluate selection                                               | `evaluate (selection)`                   | 🔸 |
| `g==` | n | mini.operators: evaluate current line                                            | `evaluate (line)`                        | 🔸 |
| `gm` | n | mini.operators: duplicate text over motion                                       | `multiply (motion)`                      | 🔸 |
| `gm` | x | mini.operators: duplicate selection                                              | `multiply (selection)`                   | 🔸 |
| `gmm` | n | mini.operators: duplicate current line                                           | `multiply (line)`                        | 🔸 |
| `gr` | n | mini.operators: replace text with register                                       | `replace w/ register (motion)`           | 🔸 |
| `gr` | x | mini.operators: replace selection with register                                  | `replace w/ register (selection)`        | 🔸 |
| `grr` | n | mini.operators: replace line with register                                       | `replace w/ register (line)`             | 🔸 |
| `gs` | n | mini.operators: sort text over motion                                            | `sort (motion)`                          | 🔸 |
| `gs` | x | mini.operators: sort selection                                                   | `sort (selection)`                       | 🔸 |
| `gss` | n | mini.operators: sort current line                                                | `sort (line)`                            | 🔸 |
| `gx` | n | mini.operators: exchange region (2-step swap)                                    | `exchange (motion)`                      | 🔸 |
| `gx` | x | mini.operators: exchange selection                                               | `exchange (selection)`                   | 🔸 |
| `gxx` | n | mini.operators: exchange current line                                            | `exchange (line)`                        | 🔸 |

### mini.splitjoin <a id="plugin-minisplitjoin"></a>

includes 1 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `gS` | n,x | mini.splitjoin: split if single line, join if multiline                          | `toggle split/join`                      | 🔸 |

### neogit <a id="plugin-neogit"></a>

Defined in: `lua/plugins/neogit.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>gg` | n | Open Neogit                                                                      | `<cmd>Neogit<CR>`                        |  |

### nvim-dap-ui <a id="plugin-nvim-dap-ui"></a>

Defined in: `lua/plugins/dap_ui.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<F3>b` | n | Debug: toggle breakpoint                                                         | `dap.toggle_breakpoint`                  |  |
| `<F3>bd` | n | Debug: clear all breakpoints                                                     | `dap.clear_breakpoints`                  |  |
| `<F3>C` | n | Debug: run to cursor                                                             | `dap.run_to_cursor`                      |  |
| `<F3>cc` | n | Debug: continue                                                                  | `dap.continue`                           |  |
| `<F3>e` | n | Debug: evaluate expression                                                       | `dapui.eval`                             |  |
| `<F3>j` | n | Debug: go down a stack frame                                                     | `dap.down`                               |  |
| `<F3>k` | n | Debug: go up a stack frame                                                       | `dap.up`                                 |  |
| `<F3>q` | n | Debug: stop session                                                              | `dap.terminate`                          |  |
| `<F3>r` | n | Debug: toggle REPL                                                               | `dap.repl.toggle`                        |  |
| `<F3>uf` | n | Debug: toggle floating UI element                                                | `dapui.float_element`                    |  |
| `<F3>uu` | n | Debug: toggle UI                                                                 | `dapui.toggle`                           |  |
| `<F5>` | n | Debug: continue                                                                  | `dap.continue`                           |  |
| `<F6>` | n | Debug: step out                                                                  | `dap.step_out`                           |  |
| `<F7>` | n | Debug: step over                                                                 | `dap.step_over`                          |  |
| `<F8>` | n | Debug: run to cursor                                                             | `dap.run_to_cursor`                      |  |
| `<F9>` | n | Debug: step into                                                                 | `dap.step_into`                          |  |

### nvim-lint <a id="plugin-nvim-lint"></a>

Defined in: `lua/plugins/linter.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>cl` | n | Trigger linting                                                                  | `lint.try_lint`                          |  |

### nvim-lspconfig <a id="plugin-nvim-lspconfig"></a>

Defined in: `lua/plugins/lspconfig.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-s>` | i | LSP: signature help                                                              | `vim.lsp.buf.signature_help`             |  |
| `<leader>lc` | n | LSP: run CodeLens action                                                         | `vim.lsp.codelens.run`                   |  |
| `<leader>lr` | n | LSP: rename symbol                                                               | `vim.lsp.buf.rename`                     |  |
| `<leader>lSr` | n | LSP: restart                                                                     | `<cmd>lsp restart<CR>`                   |  |
| `gD` | n | LSP: go to declaration                                                           | `vim.lsp.buf.declaration`                |  |
| `gd` | n | LSP: definitions (Telescope)                                                     | `<cmd>Telescope lsp_definitions<CR>`     |  |
| `gi` | n | LSP: implementations (Telescope)                                                 | `<cmd>Telescope lsp_implementations<CR>` |  |
| `gR` | n | LSP: references (Telescope)                                                      | `<cmd>Telescope lsp_references<CR>`      |  |
| `gt` | n | LSP: type definitions (Telescope)                                                | `<cmd>Telescope lsp_type_implementations…` |  |
| `K` | n | LSP: hover documentation                                                         | `vim.lsp.buf.hover`                      |  |

### nvim-origami <a id="plugin-nvim-origami"></a>

includes 4 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `$` | n | Origami: unfold recursively on folded line, else $                               | `unfold recursively or normal $`         | 🔸 |
| `h` | n | Origami: fold when at/before first non-blank, else h                             | `fold or normal h`                       | 🔸 |
| `l` | n | Origami: unfold folded line, else l                                              | `unfold or normal l`                     | 🔸 |
| `^` | n | Origami: fold recursively when before first non-blank, else ^                    | `fold recursively or normal ^`           | 🔸 |

### nvim-surround <a id="plugin-nvim-surround"></a>

includes 11 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-g>s` | i | Surround: add pair around the cursor                                             | `surround at cursor`                     | 🔸 |
| `<C-g>S` | i | Surround: add pair around cursor, on new lines                                   | `surround at cursor (new lines)`         | 🔸 |
| `cS` | n | Surround: change a pair onto new lines                                           | `change surround (new lines)`            | 🔸 |
| `cs{target}{replacement}` | n | Surround: change a surrounding pair                                              | `change surround`                        | 🔸 |
| `ds{char}` | n | Surround: delete a surrounding pair                                              | `delete surround`                        | 🔸 |
| `gS` | x | Surround: add pair around selection, on new lines                                | `surround selection (new lines)`         | 🔸 |
| `S` | x | Surround: add pair around visual selection                                       | `surround selection`                     | 🔸 |
| `yS` | n | Surround: add pair around motion, on new lines                                   | `add surround around motion (new lines)` | 🔸 |
| `yss` | n | Surround: add pair around current line                                           | `add surround around line`               | 🔸 |
| `ySS` | n | Surround: add pair around line, on new lines                                     | `add surround around line (new lines)`   | 🔸 |
| `ys{motion}{char}` | n | Surround: add pair around a motion                                               | `add surround around motion`             | 🔸 |

### nvim-treesitter <a id="plugin-nvim-treesitter"></a>

Defined in: `lua/plugins/treesitter.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<A-v>` | n | Incremental selection: start / expand node                                       | `init_selection`                         |  |
| `<A-v>` | x | Incremental selection: expand to next node                                       | `node_incremental`                       |  |
| `<A-V>` | x | Incremental selection: shrink node                                               | `node_decremental`                       |  |
| `<end>` | n,x,o | Repeat last textobject move forward                                              | `repeat_last_move (forward)`             |  |
| `<home>` | n,x,o | Repeat last textobject move backward                                             | `repeat_last_move (backward)`            |  |
| `<leader>a` | n | Swap parameter with next                                                         | `swap_next @parameter.inner`             |  |
| `<leader>A` | n | Swap parameter with previous                                                     | `swap_previous @parameter.inner`         |  |
| `==` | x,o | Textobject: assignment (outer)                                                   | `@assignment.outer`                      |  |
| `=l` | x,o | Textobject: assignment left-hand side                                            | `@assignment.lhs`                        |  |
| `=r` | x,o | Textobject: assignment right-hand side                                           | `@assignment.rhs`                        |  |
| `aa` | x,o | Textobject: parameter (outer)                                                    | `@parameter.outer`                       |  |
| `ab` | x,o | Textobject: block (outer)                                                        | `@block.outer`                           |  |
| `ac` | x,o | Textobject: comment (outer)                                                      | `@comment.outer`                         |  |
| `af` | x,o | Textobject: call (outer)                                                         | `@call.outer`                            |  |
| `ai` | x,o | Textobject: conditional (outer)                                                  | `@conditional.outer`                     |  |
| `al` | x,o | Textobject: loop (outer)                                                         | `@loop.outer`                            |  |
| `am` | x,o | Textobject: function (outer)                                                     | `@function.outer`                        |  |
| `an` | x,o | Textobject: number (inner)                                                       | `@number.inner`                          |  |
| `ar` | x,o | Textobject: return (outer)                                                       | `@return.outer`                          |  |
| `at` | x,o | Textobject: class (outer)                                                        | `@class.outer`                           |  |
| `ia` | x,o | Textobject: parameter (inner)                                                    | `@parameter.inner`                       |  |
| `ib` | x,o | Textobject: block (inner)                                                        | `@block.inner`                           |  |
| `ic` | x,o | Textobject: comment (outer)                                                      | `@comment.outer`                         |  |
| `if` | x,o | Textobject: call (inner)                                                         | `@call.inner`                            |  |
| `ii` | x,o | Textobject: conditional (inner)                                                  | `@conditional.inner`                     |  |
| `il` | x,o | Textobject: loop (inner)                                                         | `@loop.inner`                            |  |
| `im` | x,o | Textobject: function (inner)                                                     | `@function.inner`                        |  |
| `in` | x,o | Textobject: number (inner)                                                       | `@number.inner`                          |  |
| `ir` | x,o | Textobject: return (inner)                                                       | `@return.inner`                          |  |
| `it` | x,o | Textobject: class (inner)                                                        | `@class.inner`                           |  |

### oil.nvim <a id="plugin-oilnvim"></a>

Defined in: `lua/plugins/oil.lua`; includes 16 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `-` | n | Oil: go to parent directory                                                      | `actions.parent`                         |  |
| `<CR>` | n | Oil: open entry                                                                  | `actions.select`                         |  |
| `<leader>ed` | n | Oil: edit current file's directory                                               | `<cmd>edit %:p:h<CR>`                    |  |
| `<leader>eD` | n | Oil: edit current working directory                                              | `<cmd>edit .<CR>`                        |  |
| `g.` | n | Oil: toggle hidden files                                                         | `actions.toggle_hidden`                  |  |
| `g?` | n | Oil: show help                                                                   | `actions.show_help`                      |  |
| `gh` | n | Oil: open entry in horizontal split                                              | `actions.select horizontal`              |  |
| `gp` | n | Oil: preview entry                                                               | `actions.preview`                        |  |
| `gq` | n | Oil: close                                                                       | `actions.close`                          |  |
| `gr` | n | Oil: refresh                                                                     | `actions.refresh`                        |  |
| `gs` | n | Oil: change sort                                                                 | `actions.change_sort`                    |  |
| `gt` | n | Oil: open entry in new tab                                                       | `actions.select tab`                     |  |
| `gv` | n | Oil: open entry in vertical split                                                | `actions.select vertical`                |  |
| `gx` | n | Oil: open externally                                                             | `actions.open_external`                  |  |
| `g\` | n | Oil: toggle trash                                                                | `actions.toggle_trash`                   |  |
| `_` | n | Oil: open current working directory                                              | `actions.open_cwd`                       |  |
| `'` | n | Oil: :cd to directory                                                            | `actions.cd`                             |  |
| `~` | n | Oil: :tcd to directory                                                           | `actions.cd scope=tab`                   |  |
| `-` | n | Oil (default): go to parent directory                                            | `actions.parent`                         | 🔸 |
| `<C-c>` | n | Oil (default): close buffer                                                      | `actions.close`                          | 🔸 |
| `<C-h>` | n,v | Oil (default): open in horizontal split                                          | `actions.select horizontal`              | 🔸 |
| `<C-l>` | n,v | Oil (default): refresh buffer                                                    | `actions.refresh`                        | 🔸 |
| `<C-p>` | n,v | Oil (default): preview entry                                                     | `actions.preview`                        | 🔸 |
| `<C-s>` | n,v | Oil (default): open in vertical split                                            | `actions.select vertical`                | 🔸 |
| `<C-t>` | n,v | Oil (default): open in new tab                                                   | `actions.select tab`                     | 🔸 |
| `<CR>` | n,v | Oil (default): open entry                                                        | `actions.select`                         | 🔸 |
| `g.` | n | Oil (default): toggle hidden files                                               | `actions.toggle_hidden`                  | 🔸 |
| `g?` | n | Oil (default): show help                                                         | `actions.show_help`                      | 🔸 |
| `gs` | n | Oil (default): change sort order                                                 | `actions.change_sort`                    | 🔸 |
| `gx` | n,v | Oil (default): open with system app                                              | `actions.open_external`                  | 🔸 |
| `g\` | n | Oil (default): toggle trash view                                                 | `actions.toggle_trash`                   | 🔸 |
| `g~` | n | Oil (default): :tcd to directory                                                 | `actions.cd scope=tab`                   | 🔸 |
| `_` | n | Oil (default): open current working directory                                    | `actions.open_cwd`                       | 🔸 |
| `'` | n | Oil (default): :cd to directory                                                  | `actions.cd`                             | 🔸 |

### snacks.nvim <a id="plugin-snacksnvim"></a>

Defined in: `lua/plugins/snacks.nvim.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader><leader>sn` | n | Show notification history                                                        | `Snacks.notifier.show_history()`         |  |

### telescope-undo.nvim <a id="plugin-telescope-undonvim"></a>

Defined in: `lua/plugins/telescope_undo.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>u` | n | Browse undo history                                                              | `<cmd>Telescope undo<cr>`                |  |

### telescope.nvim <a id="plugin-telescopenvim"></a>

Defined in: `lua/plugins/telescope.lua`; includes 16 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<C-j>` | i | Telescope picker: move to next item                                              | `actions.move_selection_next`            |  |
| `<C-k>` | i | Telescope picker: move to previous item                                          | `actions.move_selection_previous`        |  |
| `<C-q>` | i | Telescope picker: send selection to quickfix                                     | `send_selected_to_qflist + open_qflist`  |  |
| `<leader>f?` | n | Fuzzy find: help tags                                                            | `<cmd>Telescope help_tags<cr>`           |  |
| `<leader>fb` | n | Fuzzy find: buffers                                                              | `<cmd>Telescope buffers<cr>`             |  |
| `<leader>ff` | n | Fuzzy find: files                                                                | `<cmd>Telescope find_files<cr>`          |  |
| `<leader>fF` | n | Fuzzy find: hidden files                                                         | `<cmd>Telescope find_files hidden=true<c…` |  |
| `<leader>fg` | n | Fuzzy find: live grep                                                            | `<cmd>Telescope live_grep<cr>`           |  |
| `<leader>fh` | n | Fuzzy find: harpoon marks                                                        | `<cmd>Telescope harpoon marks<CR>`       |  |
| `<leader>fj` | n | Fuzzy find: jumplist entries                                                     | `<cmd>Telescope jumplist<CR>`            |  |
| `<leader>fk` | n | Fuzzy find: keymaps                                                              | `<cmd>Telescope keymaps<cr>`             |  |
| `<leader>fK` | n | Fuzzy find: keymaps by plugin                                                    | `<cmd>lua require('keymap_registry').pic…` |  |
| `<leader>fr` | n | Fuzzy find: recent files                                                         | `<cmd>Telescope oldfiles<cr>`            |  |
| `<leader>ft` | n | Fuzzy find: TODO comments                                                        | `<cmd>TodoTelescope<CR>`                 |  |
| `<C-c>` | i | Telescope (default): close picker                                                | `close`                                  | 🔸 |
| `<C-d>` | i,n | Telescope (default): scroll preview down                                         | `preview_scrolling_down`                 | 🔸 |
| `<C-n>` | i | Telescope (default): next result                                                 | `move_selection_next`                    | 🔸 |
| `<C-p>` | i | Telescope (default): previous result                                             | `move_selection_previous`                | 🔸 |
| `<C-q>` | i,n | Telescope (default): send all to quickfix                                        | `send_to_qflist + open_qflist`           | 🔸 |
| `<C-t>` | i,n | Telescope (default): open in new tab                                             | `select_tab`                             | 🔸 |
| `<C-u>` | i,n | Telescope (default): scroll preview up                                           | `preview_scrolling_up`                   | 🔸 |
| `<C-v>` | i,n | Telescope (default): open in vertical split                                      | `select_vertical`                        | 🔸 |
| `<C-x>` | i,n | Telescope (default): open in horizontal split                                    | `select_horizontal`                      | 🔸 |
| `<CR>` | i,n | Telescope (default): open selected entry                                         | `select_default`                         | 🔸 |
| `<Down>` | i | Telescope (default): next result                                                 | `move_selection_next`                    | 🔸 |
| `<Esc>` | n | Telescope (default): close picker                                                | `close`                                  | 🔸 |
| `<M-q>` | i,n | Telescope (default): send selected to quickfix                                   | `send_selected_to_qflist + open_qflist`  | 🔸 |
| `<Tab>` | i,n | Telescope (default): toggle multi-selection                                      | `toggle_selection + move worse`          | 🔸 |
| `<Up>` | i | Telescope (default): previous result                                             | `move_selection_previous`                | 🔸 |
| `?` | n | Telescope (default): show mappings help                                          | `which_key`                              | 🔸 |

### trouble.nvim <a id="plugin-troublenvim"></a>

Defined in: `lua/plugins/trouble.lua`; includes 11 implicit default(s) 🔸

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>lo` | n | Trouble: location list                                                           | `<cmd>Trouble loclist toggle<cr>`        |  |
| `<leader>lq` | n | Trouble: quickfix list                                                           | `<cmd>Trouble qflist toggle<cr>`         |  |
| `<leader>ls` | n | Trouble: document symbols                                                        | `<cmd>Trouble symbols toggle focus=false…` |  |
| `<leader>lSl` | n | Trouble: LSP definitions/references                                              | `<cmd>Trouble lsp toggle focus=false win…` |  |
| `<C-s>` | n | Trouble window: jump in horizontal split                                         | `jump (horizontal split)`                | 🔸 |
| `<C-v>` | n | Trouble window: jump in vertical split                                           | `jump (vertical split)`                  | 🔸 |
| `<CR>` | n | Trouble window: jump to item                                                     | `jump`                                   | 🔸 |
| `?` | n | Trouble window: show help                                                        | `help`                                   | 🔸 |
| `o` | n | Trouble window: jump to item and close                                           | `jump + close`                           | 🔸 |
| `p` | n | Trouble window: preview item                                                     | `preview`                                | 🔸 |
| `P` | n | Trouble window: toggle auto preview                                              | `toggle preview`                         | 🔸 |
| `q` | n | Trouble window: close                                                            | `close`                                  | 🔸 |
| `r` | n | Trouble window: refresh                                                          | `refresh`                                | 🔸 |
| `{` | n | Trouble window: previous item                                                    | `previous item`                          | 🔸 |
| `}` | n | Trouble window: next item                                                        | `next item`                              | 🔸 |

### vim-maximizer <a id="plugin-vim-maximizer"></a>

Defined in: `lua/plugins/maximizer.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>sm` | n | Toggle split maximize                                                            | `<cmd>MaximizerToggle<CR>`               |  |

### vim-tmux-navigator <a id="plugin-vim-tmux-navigator"></a>

Defined in: `lua/plugins/tmux-naivation.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<c-h>` | n | Navigate to left pane/split                                                      | `<cmd>TmuxNavigateLeft<cr>`              |  |
| `<c-j>` | n | Navigate to lower pane/split                                                     | `<cmd>TmuxNavigateDown<cr>`              |  |
| `<c-k>` | n | Navigate to upper pane/split                                                     | `<cmd>TmuxNavigateUp<cr>`                |  |
| `<c-l>` | n | Navigate to right pane/split                                                     | `<cmd>TmuxNavigateRight<cr>`             |  |
| `<c-\>` | n | Navigate to previous pane/split                                                  | `<cmd>TmuxNavigatePrevious<cr>`          |  |

### which-key.nvim <a id="plugin-which-keynvim"></a>

Defined in: `lua/plugins/whichkey.lua`

| Key | Mode | Description                                                                      | Action                                   | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- |
| `<leader>?` | n | Show all keymaps (which-key)                                                     | `require('which-key').show({ global = tr…` |  |

## Grouped Logically <a id="sec-logical"></a>

All keybindings organized by their logical purpose, regardless of file or
plugin.

### AI Chat <a id="group-ai-chat"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-c>` | n,i | CodeCompanion chat: close buffer                                                 | `chat: close`                            | `codecompanion.nvim` | 🔸 |
| `<C-s>` | n,i | CodeCompanion chat: send message                                                 | `chat: send`                             | `codecompanion.nvim` | 🔸 |
| `<C-_>` | i | CodeCompanion chat: open completion menu                                         | `chat: completion menu`                  | `codecompanion.nvim` | 🔸 |
| `<CR>` | n | CodeCompanion chat: send message                                                 | `chat: send`                             | `codecompanion.nvim` | 🔸 |
| `?` | n | CodeCompanion chat: show keymap help                                             | `chat: options/help`                     | `codecompanion.nvim` | 🔸 |
| `ga` | n | CodeCompanion chat: change adapter/model                                         | `chat: change adapter`                   | `codecompanion.nvim` | 🔸 |
| `gc` | n | CodeCompanion chat: insert empty codeblock                                       | `chat: insert codeblock`                 | `codecompanion.nvim` | 🔸 |
| `gd` | n | CodeCompanion chat: show debug info                                              | `chat: debug info`                       | `codecompanion.nvim` | 🔸 |
| `gf` | n | CodeCompanion chat: fold all codeblocks                                          | `chat: fold codeblocks`                  | `codecompanion.nvim` | 🔸 |
| `gr` | n | CodeCompanion chat: regenerate last response                                     | `chat: regenerate`                       | `codecompanion.nvim` | 🔸 |
| `gs` | n | CodeCompanion chat: toggle system prompt                                         | `chat: toggle system prompt`             | `codecompanion.nvim` | 🔸 |
| `gx` | n | CodeCompanion chat: clear all messages                                           | `chat: clear`                            | `codecompanion.nvim` | 🔸 |
| `gy` | n | CodeCompanion chat: yank last codeblock                                          | `chat: yank codeblock`                   | `codecompanion.nvim` | 🔸 |
| `q` | n | CodeCompanion chat: stop current request                                         | `chat: stop request`                     | `codecompanion.nvim` | 🔸 |
| `[[` | n | CodeCompanion chat: jump to previous message header                              | `chat: previous header`                  | `codecompanion.nvim` | 🔸 |
| `]]` | n | CodeCompanion chat: jump to next message header                                  | `chat: next header`                      | `codecompanion.nvim` | 🔸 |
| `{` | n | CodeCompanion chat: open previous chat                                           | `chat: previous chat`                    | `codecompanion.nvim` | 🔸 |
| `}` | n | CodeCompanion chat: open next chat                                               | `chat: next chat`                        | `codecompanion.nvim` | 🔸 |

### Clipboard <a id="group-clipboard"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<leader>p` | n | Paste from system clipboard                                                      | `"+p`                                    | _core_ |  |
| `<leader>p` | v | Paste over selection without yanking                                             | `"_dP`                                   | _core_ |  |
| `<leader>y` | n | Yank to system clipboard                                                         | `"+y`                                    | _core_ |  |
| `<leader>y` | v | Yank selection to system clipboard                                               | `"+y`                                    | _core_ |  |

### Command <a id="group-command"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `:` | n,x | Enter Command-line (Ex) mode                                                     | `(command)`                              | _core_ | 🔹 |

### Comments <a id="group-comments"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `gb` | x | Comment: toggle selection (blockwise)                                            | `toggle blockwise comment (selection)`   | `Comment.nvim` | 🔸 |
| `gbc` | n | Comment: toggle current line (blockwise)                                         | `toggle blockwise comment (line)`        | `Comment.nvim` | 🔸 |
| `gb{motion}` | n | Comment: blockwise comment over a motion                                         | `toggle blockwise comment (operator)`    | `Comment.nvim` | 🔸 |
| `gc` | x | Comment: toggle selection (linewise)                                             | `toggle linewise comment (selection)`    | `Comment.nvim` | 🔸 |
| `gcA` | n | Comment: append comment at end of line                                           | `comment end of line + insert`           | `Comment.nvim` | 🔸 |
| `gcc` | n | Comment: toggle current line (linewise)                                          | `toggle linewise comment (line)`         | `Comment.nvim` | 🔸 |
| `gco` | n | Comment: add comment on line below                                               | `comment line below + insert`            | `Comment.nvim` | 🔸 |
| `gcO` | n | Comment: add comment on line above                                               | `comment line above + insert`            | `Comment.nvim` | 🔸 |
| `gc{motion}` | n | Comment: linewise comment over a motion                                          | `toggle linewise comment (operator)`     | `Comment.nvim` | 🔸 |

### Completion <a id="group-completion"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-b>` | i | Completion: scroll documentation up                                              | `scroll_documentation_up / fallback`     | `blink.cmp` |  |
| `<C-b>` | i | Completion: scroll documentation up                                              | `scroll docs up`                         | `blink.cmp` | 🔸 |
| `<C-e>` | i | Completion: cancel / hide menu                                                   | `hide menu`                              | `blink.cmp` | 🔸 |
| `<C-f>` | i | Completion: scroll documentation down                                            | `scroll_documentation_down / fallback`   | `blink.cmp` |  |
| `<C-f>` | i | Completion: scroll documentation down                                            | `scroll docs down`                       | `blink.cmp` | 🔸 |
| `<C-k>` | i | Completion: toggle signature help                                                | `toggle signature help`                  | `blink.cmp` | 🔸 |
| `<C-n>` | i | Completion: select next item                                                     | `select next`                            | `blink.cmp` | 🔸 |
| `<C-p>` | i | Completion: select previous item                                                 | `select previous`                        | `blink.cmp` | 🔸 |
| `<C-space>` | i | Completion: open menu or toggle docs                                             | `show / show_documentation / hide_docume…` | `blink.cmp` |  |
| `<C-space>` | i | Completion: open menu or toggle docs                                             | `show menu / toggle docs`                | `blink.cmp` | 🔸 |
| `<C-y>` | i | Completion: accept selected item                                                 | `accept item`                            | `blink.cmp` | 🔸 |
| `<Down>` | i | Completion: select next item                                                     | `select next`                            | `blink.cmp` | 🔸 |
| `<S-Tab>` | i | Completion: jump to previous snippet placeholder                                 | `prev snippet placeholder`               | `blink.cmp` | 🔸 |
| `<Tab>` | i | Completion: jump to next snippet placeholder                                     | `next snippet placeholder`               | `blink.cmp` | 🔸 |
| `<Up>` | i | Completion: select previous item                                                 | `select previous`                        | `blink.cmp` | 🔸 |

### Copilot <a id="group-copilot"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-]>` | i | Copilot: dismiss current suggestion                                              | `dismiss suggestion`                     | `copilot.lua` | 🔸 |
| `<CR>` | n | Copilot panel: accept suggestion under cursor                                    | `panel: accept`                          | `copilot.lua` | 🔸 |
| `<M-CR>` | n | Copilot: open suggestion panel                                                   | `open panel`                             | `copilot.lua` | 🔸 |
| `<M-l>` | i | Copilot: accept inline suggestion                                                | `accept suggestion`                      | `copilot.lua` | 🔸 |
| `<M-[>` | i | Copilot: show previous suggestion                                                | `prev suggestion`                        | `copilot.lua` | 🔸 |
| `<M-]>` | i | Copilot: show next suggestion                                                    | `next suggestion`                        | `copilot.lua` | 🔸 |
| `gr` | n | Copilot panel: refresh suggestions                                               | `panel: refresh`                         | `copilot.lua` | 🔸 |
| `[[` | n | Copilot panel: jump to previous suggestion                                       | `panel: prev suggestion`                 | `copilot.lua` | 🔸 |
| `]]` | n | Copilot panel: jump to next suggestion                                           | `panel: next suggestion`                 | `copilot.lua` | 🔸 |

### Debug <a id="group-debug"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<F3>b` | n | Debug: toggle breakpoint                                                         | `dap.toggle_breakpoint`                  | `nvim-dap-ui` |  |
| `<F3>bd` | n | Debug: clear all breakpoints                                                     | `dap.clear_breakpoints`                  | `nvim-dap-ui` |  |
| `<F3>C` | n | Debug: run to cursor                                                             | `dap.run_to_cursor`                      | `nvim-dap-ui` |  |
| `<F3>cc` | n | Debug: continue                                                                  | `dap.continue`                           | `nvim-dap-ui` |  |
| `<F3>e` | n | Debug: evaluate expression                                                       | `dapui.eval`                             | `nvim-dap-ui` |  |
| `<F3>j` | n | Debug: go down a stack frame                                                     | `dap.down`                               | `nvim-dap-ui` |  |
| `<F3>k` | n | Debug: go up a stack frame                                                       | `dap.up`                                 | `nvim-dap-ui` |  |
| `<F3>q` | n | Debug: stop session                                                              | `dap.terminate`                          | `nvim-dap-ui` |  |
| `<F3>r` | n | Debug: toggle REPL                                                               | `dap.repl.toggle`                        | `nvim-dap-ui` |  |
| `<F3>uf` | n | Debug: toggle floating UI element                                                | `dapui.float_element`                    | `nvim-dap-ui` |  |
| `<F3>uu` | n | Debug: toggle UI                                                                 | `dapui.toggle`                           | `nvim-dap-ui` |  |
| `<F5>` | n | Debug: continue                                                                  | `dap.continue`                           | `nvim-dap-ui` |  |
| `<F6>` | n | Debug: step out                                                                  | `dap.step_out`                           | `nvim-dap-ui` |  |
| `<F7>` | n | Debug: step over                                                                 | `dap.step_over`                          | `nvim-dap-ui` |  |
| `<F8>` | n | Debug: run to cursor                                                             | `dap.run_to_cursor`                      | `nvim-dap-ui` |  |
| `<F9>` | n | Debug: step into                                                                 | `dap.step_into`                          | `nvim-dap-ui` |  |

### Diagnostics <a id="group-diagnostics"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-F14>` | n | Go to previous diagnostic                                                        | `:Lspsaga diagnostic_jump_prev<CR>`      | `lspsaga.nvim` |  |
| `<C-s>` | n | Trouble window: jump in horizontal split                                         | `jump (horizontal split)`                | `trouble.nvim` | 🔸 |
| `<C-v>` | n | Trouble window: jump in vertical split                                           | `jump (vertical split)`                  | `trouble.nvim` | 🔸 |
| `<CR>` | n | Trouble window: jump to item                                                     | `jump`                                   | `trouble.nvim` | 🔸 |
| `<F14>` | n | Go to next diagnostic                                                            | `:Lspsaga diagnostic_jump_next<CR>`      | `lspsaga.nvim` |  |
| `<leader>cl` | n | Trigger linting                                                                  | `lint.try_lint`                          | `nvim-lint` |  |
| `<leader>lo` | n | Trouble: location list                                                           | `<cmd>Trouble loclist toggle<cr>`        | `trouble.nvim` |  |
| `<leader>lq` | n | Trouble: quickfix list                                                           | `<cmd>Trouble qflist toggle<cr>`         | `trouble.nvim` |  |
| `<leader>ls` | n | Trouble: document symbols                                                        | `<cmd>Trouble symbols toggle focus=false…` | `trouble.nvim` |  |
| `<leader>lSl` | n | Trouble: LSP definitions/references                                              | `<cmd>Trouble lsp toggle focus=false win…` | `trouble.nvim` |  |
| `?` | n | Trouble window: show help                                                        | `help`                                   | `trouble.nvim` | 🔸 |
| `o` | n | Trouble window: jump to item and close                                           | `jump + close`                           | `trouble.nvim` | 🔸 |
| `p` | n | Trouble window: preview item                                                     | `preview`                                | `trouble.nvim` | 🔸 |
| `P` | n | Trouble window: toggle auto preview                                              | `toggle preview`                         | `trouble.nvim` | 🔸 |
| `q` | n | Trouble window: close                                                            | `close`                                  | `trouble.nvim` | 🔸 |
| `r` | n | Trouble window: refresh                                                          | `refresh`                                | `trouble.nvim` | 🔸 |
| `{` | n | Trouble window: previous item                                                    | `previous item`                          | `trouble.nvim` | 🔸 |
| `}` | n | Trouble window: next item                                                        | `next item`                              | `trouble.nvim` | 🔸 |

### Diagnostics Hydra <a id="group-diagnostics-hydra"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<Esc>` | hydra(diagnostics) | Leave the hydra                                                                  | `exit hydra`                             | `hydra.nvim` |  |
| `<leader>ld` | n → hydra(diagnostics) | Enter the red hydra "diagnostics"                                                | `enter hydra`                            | `hydra.nvim` |  |
| `b` | hydra(diagnostics) | Toggle scope (buffer/project)                                                    | `toggle scope buffer/project`            | `hydra.nvim` |  |
| `d` | hydra(diagnostics) | Next diagnostic                                                                  | `goto next diagnostic`                   | `hydra.nvim` |  |
| `D` | hydra(diagnostics) | Previous diagnostic                                                              | `goto previous diagnostic`               | `hydra.nvim` |  |
| `e` | hydra(diagnostics) | Next error                                                                       | `goto next ERROR diagnostic`             | `hydra.nvim` |  |
| `E` | hydra(diagnostics) | Previous error                                                                   | `goto previous ERROR diagnostic`         | `hydra.nvim` |  |
| `h` | hydra(diagnostics) | Next hint                                                                        | `goto next HINT diagnostic`              | `hydra.nvim` |  |
| `H` | hydra(diagnostics) | Previous hint                                                                    | `goto previous HINT diagnostic`          | `hydra.nvim` |  |
| `i` | hydra(diagnostics) | Next info                                                                        | `goto next INFO diagnostic`              | `hydra.nvim` |  |
| `I` | hydra(diagnostics) | Previous info                                                                    | `goto previous INFO diagnostic`          | `hydra.nvim` |  |
| `q` | hydra(diagnostics) | Leave the hydra                                                                  | `exit hydra`                             | `hydra.nvim` |  |
| `tc` | hydra(diagnostics) | Toggle CodeLenses                                                                | `toggle codelens_enabled`                | `hydra.nvim` |  |
| `ti` | hydra(diagnostics) | Toggle inlay hints                                                               | `toggle inlay hints`                     | `hydra.nvim` |  |
| `tv` | hydra(diagnostics) | Toggle virtual_lines                                                             | `toggle diagnostic virtual_lines`        | `hydra.nvim` |  |
| `w` | hydra(diagnostics) | Next warning                                                                     | `goto next WARN diagnostic`              | `hydra.nvim` |  |
| `W` | hydra(diagnostics) | Previous warning                                                                 | `goto previous WARN diagnostic`          | `hydra.nvim` |  |
| `x` | hydra(diagnostics) | Trouble diagnostics (workspace)                                                  | `<cmd>Trouble diagnostics toggle<cr>`    | `hydra.nvim` |  |
| `X` | hydra(diagnostics) | Trouble diagnostics (buffer)                                                     | `<cmd>Trouble diagnostics toggle filter.…` | `hydra.nvim` |  |
| `{` | hydra(diagnostics) | First diagnostic                                                                 | `goto first diagnostic`                  | `hydra.nvim` |  |
| `}` | hydra(diagnostics) | Last diagnostic                                                                  | `goto last diagnostic`                   | `hydra.nvim` |  |

### Editing <a id="group-editing"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `.` | n | Repeat last change                                                               | `(edit)`                                 | _core_ | 🔹 |
| `<` | n | Indent line left                                                                 | `<<`                                     | _core_ |  |
| `<` | v | Indent left, keep selection                                                      | `<gv`                                    | _core_ |  |
| `<C-r>` | n | Redo                                                                             | `(edit)`                                 | _core_ | 🔹 |
| `<leader>+` | n | Increment number under cursor                                                    | `<C-a>`                                  | _core_ |  |
| `<leader>-` | n | Decrement number under cursor                                                    | `<C-x>`                                  | _core_ |  |
| `<leader>c` | n | Change (yank into default register)                                              | `c`                                      | _core_ |  |
| `<leader>cf` | n,v | Format file or range                                                             | `conform.format`                         | `conform.nvim` |  |
| `<leader>d` | n | Delete (yank into default register)                                              | `d`                                      | _core_ |  |
| `=` | n,x | Auto-indent {motion}/selection                                                   | `(operator)`                             | _core_ | 🔹 |
| `==` | n | Auto-indent current line                                                         | `(operator)`                             | _core_ | 🔹 |
| `>` | n | Indent line right                                                                | `>>`                                     | _core_ |  |
| `>` | v | Indent right, keep selection                                                     | `>gv`                                    | _core_ |  |
| `a` | n | Insert after cursor                                                              | `(edit)`                                 | _core_ | 🔹 |
| `A` | n | Insert at end of line                                                            | `(edit)`                                 | _core_ | 🔹 |
| `c` | n | Change into black-hole register                                                  | `"_c`                                    | _core_ |  |
| `C` | n | Change to end of line                                                            | `(operator)`                             | _core_ | 🔹 |
| `c` | x | Change {motion}/selection                                                        | `(operator)`                             | _core_ | 🔹 |
| `cc` | n | Change line                                                                      | `(operator)`                             | _core_ | 🔹 |
| `d` | n | Delete into black-hole register                                                  | `"_d`                                    | _core_ |  |
| `D` | n | Delete to end of line                                                            | `(operator)`                             | _core_ | 🔹 |
| `d` | x | Delete {motion}/selection                                                        | `(operator)`                             | _core_ | 🔹 |
| `dd` | n | Delete line                                                                      | `(operator)`                             | _core_ | 🔹 |
| `gJ` | n | Join line below without a space                                                  | `(edit)`                                 | _core_ | 🔹 |
| `gq` | x | Format {motion}/selection                                                        | `(operator)`                             | _core_ | 🔹 |
| `gS` | n,x | mini.splitjoin: split if single line, join if multiline                          | `toggle split/join`                      | `mini.splitjoin` | 🔸 |
| `gu` | n,x | Lowercase {motion}/selection                                                     | `(operator)`                             | _core_ | 🔹 |
| `gU` | n,x | Uppercase {motion}/selection                                                     | `(operator)`                             | _core_ | 🔹 |
| `g~` | n,x | Toggle case of {motion}/selection                                                | `(operator)`                             | _core_ | 🔹 |
| `i` | n | Insert before cursor                                                             | `(edit)`                                 | _core_ | 🔹 |
| `I` | n | Insert at first non-blank                                                        | `(edit)`                                 | _core_ | 🔹 |
| `J` | n | Join line below with a space                                                     | `(edit)`                                 | _core_ | 🔹 |
| `J` | x | Move selected block down                                                         | `:move '>+1<CR>gv=gv`                    | _core_ |  |
| `K` | x | Move selected block up                                                           | `:move '<-2<CR>gv=gv`                    | _core_ |  |
| `o` | n | Open new line below and insert                                                   | `(edit)`                                 | _core_ | 🔹 |
| `O` | n | Open new line above and insert                                                   | `(edit)`                                 | _core_ | 🔹 |
| `p` | n | Paste after cursor                                                               | `(edit)`                                 | _core_ | 🔹 |
| `P` | n | Paste before cursor                                                              | `(edit)`                                 | _core_ | 🔹 |
| `Q` | n | Disable Ex mode                                                                  | `<nop>`                                  | _core_ |  |
| `r` | n | Replace single character                                                         | `(edit)`                                 | _core_ | 🔹 |
| `R` | n | Enter Replace mode                                                               | `(edit)`                                 | _core_ | 🔹 |
| `u` | n | Undo                                                                             | `(edit)`                                 | _core_ | 🔹 |
| `x` | n | Delete char without yanking                                                      | `"_x`                                    | _core_ |  |
| `X` | n | Delete character before cursor                                                   | `(edit)`                                 | _core_ | 🔹 |
| `Y` | n | Yank line (like yy)                                                              | `(operator)`                             | _core_ | 🔹 |
| `y` | n,x | Yank {motion}/selection                                                          | `(operator)`                             | _core_ | 🔹 |
| `yy` | n | Yank line                                                                        | `(operator)`                             | _core_ | 🔹 |

### File Explorer <a id="group-file-explorer"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `-` | n | Oil: go to parent directory                                                      | `actions.parent`                         | `oil.nvim` |  |
| `-` | n | Oil (default): go to parent directory                                            | `actions.parent`                         | `oil.nvim` | 🔸 |
| `<C-c>` | n | Oil (default): close buffer                                                      | `actions.close`                          | `oil.nvim` | 🔸 |
| `<C-h>` | n,v | Oil (default): open in horizontal split                                          | `actions.select horizontal`              | `oil.nvim` | 🔸 |
| `<C-l>` | n,v | Oil (default): refresh buffer                                                    | `actions.refresh`                        | `oil.nvim` | 🔸 |
| `<C-p>` | n,v | Oil (default): preview entry                                                     | `actions.preview`                        | `oil.nvim` | 🔸 |
| `<C-s>` | n,v | Oil (default): open in vertical split                                            | `actions.select vertical`                | `oil.nvim` | 🔸 |
| `<C-t>` | n,v | Oil (default): open in new tab                                                   | `actions.select tab`                     | `oil.nvim` | 🔸 |
| `<CR>` | n | Oil: open entry                                                                  | `actions.select`                         | `oil.nvim` |  |
| `<CR>` | n,v | Oil (default): open entry                                                        | `actions.select`                         | `oil.nvim` | 🔸 |
| `<leader>ed` | n | Oil: edit current file's directory                                               | `<cmd>edit %:p:h<CR>`                    | `oil.nvim` |  |
| `<leader>eD` | n | Oil: edit current working directory                                              | `<cmd>edit .<CR>`                        | `oil.nvim` |  |
| `g.` | n | Oil: toggle hidden files                                                         | `actions.toggle_hidden`                  | `oil.nvim` |  |
| `g.` | n | Oil (default): toggle hidden files                                               | `actions.toggle_hidden`                  | `oil.nvim` | 🔸 |
| `g?` | n | Oil: show help                                                                   | `actions.show_help`                      | `oil.nvim` |  |
| `g?` | n | Oil (default): show help                                                         | `actions.show_help`                      | `oil.nvim` | 🔸 |
| `gh` | n | Oil: open entry in horizontal split                                              | `actions.select horizontal`              | `oil.nvim` |  |
| `gp` | n | Oil: preview entry                                                               | `actions.preview`                        | `oil.nvim` |  |
| `gq` | n | Oil: close                                                                       | `actions.close`                          | `oil.nvim` |  |
| `gr` | n | Oil: refresh                                                                     | `actions.refresh`                        | `oil.nvim` |  |
| `gs` | n | Oil: change sort                                                                 | `actions.change_sort`                    | `oil.nvim` |  |
| `gs` | n | Oil (default): change sort order                                                 | `actions.change_sort`                    | `oil.nvim` | 🔸 |
| `gt` | n | Oil: open entry in new tab                                                       | `actions.select tab`                     | `oil.nvim` |  |
| `gv` | n | Oil: open entry in vertical split                                                | `actions.select vertical`                | `oil.nvim` |  |
| `gx` | n | Oil: open externally                                                             | `actions.open_external`                  | `oil.nvim` |  |
| `gx` | n,v | Oil (default): open with system app                                              | `actions.open_external`                  | `oil.nvim` | 🔸 |
| `g\` | n | Oil: toggle trash                                                                | `actions.toggle_trash`                   | `oil.nvim` |  |
| `g\` | n | Oil (default): toggle trash view                                                 | `actions.toggle_trash`                   | `oil.nvim` | 🔸 |
| `g~` | n | Oil (default): :tcd to directory                                                 | `actions.cd scope=tab`                   | `oil.nvim` | 🔸 |
| `_` | n | Oil: open current working directory                                              | `actions.open_cwd`                       | `oil.nvim` |  |
| `_` | n | Oil (default): open current working directory                                    | `actions.open_cwd`                       | `oil.nvim` | 🔸 |
| `'` | n | Oil: :cd to directory                                                            | `actions.cd`                             | `oil.nvim` |  |
| `'` | n | Oil (default): :cd to directory                                                  | `actions.cd`                             | `oil.nvim` | 🔸 |
| `~` | n | Oil: :tcd to directory                                                           | `actions.cd scope=tab`                   | `oil.nvim` |  |

### Folding <a id="group-folding"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `$` | n | Origami: unfold recursively on folded line, else $                               | `unfold recursively or normal $`         | `nvim-origami` | 🔸 |
| `h` | n | Origami: fold when at/before first non-blank, else h                             | `fold or normal h`                       | `nvim-origami` | 🔸 |
| `l` | n | Origami: unfold folded line, else l                                              | `unfold or normal l`                     | `nvim-origami` | 🔸 |
| `^` | n | Origami: fold recursively when before first non-blank, else ^                    | `fold recursively or normal ^`           | `nvim-origami` | 🔸 |

### Folds <a id="group-folds"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `za` | n | Toggle fold under cursor                                                         | `(fold)`                                 | _core_ | 🔹 |
| `zc` | n | Close fold under cursor                                                          | `(fold)`                                 | _core_ | 🔹 |
| `zd` | n | Delete fold under cursor                                                         | `(fold)`                                 | _core_ | 🔹 |
| `zf` | n,x | Create fold over {motion}/selection                                              | `(operator)`                             | _core_ | 🔹 |
| `zj` | n | Move to start of next fold                                                       | `(motion)`                               | _core_ | 🔹 |
| `zk` | n | Move to end of previous fold                                                     | `(motion)`                               | _core_ | 🔹 |
| `zM` | n | Close all folds                                                                  | `(fold)`                                 | _core_ | 🔹 |
| `zo` | n | Open fold under cursor                                                           | `(fold)`                                 | _core_ | 🔹 |
| `zR` | n | Open all folds                                                                   | `(fold)`                                 | _core_ | 🔹 |

### Fuzzy Find <a id="group-fuzzy-find"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-c>` | i | Telescope (default): close picker                                                | `close`                                  | `telescope.nvim` | 🔸 |
| `<C-d>` | i,n | Telescope (default): scroll preview down                                         | `preview_scrolling_down`                 | `telescope.nvim` | 🔸 |
| `<C-j>` | i | Telescope picker: move to next item                                              | `actions.move_selection_next`            | `telescope.nvim` |  |
| `<C-k>` | i | Telescope picker: move to previous item                                          | `actions.move_selection_previous`        | `telescope.nvim` |  |
| `<C-n>` | i | Telescope (default): next result                                                 | `move_selection_next`                    | `telescope.nvim` | 🔸 |
| `<C-p>` | i | Telescope (default): previous result                                             | `move_selection_previous`                | `telescope.nvim` | 🔸 |
| `<C-q>` | i | Telescope picker: send selection to quickfix                                     | `send_selected_to_qflist + open_qflist`  | `telescope.nvim` |  |
| `<C-q>` | i,n | Telescope (default): send all to quickfix                                        | `send_to_qflist + open_qflist`           | `telescope.nvim` | 🔸 |
| `<C-t>` | i,n | Telescope (default): open in new tab                                             | `select_tab`                             | `telescope.nvim` | 🔸 |
| `<C-u>` | i,n | Telescope (default): scroll preview up                                           | `preview_scrolling_up`                   | `telescope.nvim` | 🔸 |
| `<C-v>` | i,n | Telescope (default): open in vertical split                                      | `select_vertical`                        | `telescope.nvim` | 🔸 |
| `<C-x>` | i,n | Telescope (default): open in horizontal split                                    | `select_horizontal`                      | `telescope.nvim` | 🔸 |
| `<CR>` | i,n | Telescope (default): open selected entry                                         | `select_default`                         | `telescope.nvim` | 🔸 |
| `<Down>` | i | Telescope (default): next result                                                 | `move_selection_next`                    | `telescope.nvim` | 🔸 |
| `<Esc>` | n | Telescope (default): close picker                                                | `close`                                  | `telescope.nvim` | 🔸 |
| `<leader>f?` | n | Fuzzy find: help tags                                                            | `<cmd>Telescope help_tags<cr>`           | `telescope.nvim` |  |
| `<leader>fb` | n | Fuzzy find: buffers                                                              | `<cmd>Telescope buffers<cr>`             | `telescope.nvim` |  |
| `<leader>ff` | n | Fuzzy find: files                                                                | `<cmd>Telescope find_files<cr>`          | `telescope.nvim` |  |
| `<leader>fF` | n | Fuzzy find: hidden files                                                         | `<cmd>Telescope find_files hidden=true<c…` | `telescope.nvim` |  |
| `<leader>fg` | n | Fuzzy find: live grep                                                            | `<cmd>Telescope live_grep<cr>`           | `telescope.nvim` |  |
| `<leader>fh` | n | Fuzzy find: harpoon marks                                                        | `<cmd>Telescope harpoon marks<CR>`       | `telescope.nvim` |  |
| `<leader>fj` | n | Fuzzy find: jumplist entries                                                     | `<cmd>Telescope jumplist<CR>`            | `telescope.nvim` |  |
| `<leader>fk` | n | Fuzzy find: keymaps                                                              | `<cmd>Telescope keymaps<cr>`             | `telescope.nvim` |  |
| `<leader>fK` | n | Fuzzy find: keymaps by plugin                                                    | `<cmd>lua require('keymap_registry').pic…` | `telescope.nvim` |  |
| `<leader>fr` | n | Fuzzy find: recent files                                                         | `<cmd>Telescope oldfiles<cr>`            | `telescope.nvim` |  |
| `<leader>ft` | n | Fuzzy find: TODO comments                                                        | `<cmd>TodoTelescope<CR>`                 | `telescope.nvim` |  |
| `<leader>u` | n | Browse undo history                                                              | `<cmd>Telescope undo<cr>`                | `telescope-undo.nvim` |  |
| `<M-q>` | i,n | Telescope (default): send selected to quickfix                                   | `send_selected_to_qflist + open_qflist`  | `telescope.nvim` | 🔸 |
| `<Tab>` | i,n | Telescope (default): toggle multi-selection                                      | `toggle_selection + move worse`          | `telescope.nvim` | 🔸 |
| `<Up>` | i | Telescope (default): previous result                                             | `move_selection_previous`                | `telescope.nvim` | 🔸 |
| `?` | n | Telescope (default): show mappings help                                          | `which_key`                              | `telescope.nvim` | 🔸 |

### Git <a id="group-git"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `-` | n | Diffview file panel: stage/unstage entry                                         | `stage/unstage entry (file panel)`       | `diffview.nvim` | 🔸 |
| `<leader>b` | n | Diffview: toggle the file panel                                                  | `toggle file panel`                      | `diffview.nvim` | 🔸 |
| `<leader>cb` | n | Diffview merge: choose BASE                                                      | `conflict: choose base`                  | `diffview.nvim` | 🔸 |
| `<leader>cd` | n | Open Diffview                                                                    | `:DiffviewOpen<cr>`                      | `diffview.nvim` |  |
| `<leader>cD` | n | Toggle difftastic diff view                                                      | `toggle Difft diff`                      | `difft.nvim` |  |
| `<leader>co` | n | Diffview merge: choose OURS                                                      | `conflict: choose ours`                  | `diffview.nvim` | 🔸 |
| `<leader>ct` | n | Diffview merge: choose THEIRS                                                    | `conflict: choose theirs`                | `diffview.nvim` | 🔸 |
| `<leader>e` | n | Diffview: focus the file panel                                                   | `focus file panel`                       | `diffview.nvim` | 🔸 |
| `<leader>gd` | n | Gitsigns: diff this                                                              | `<cmd>Gitsigns diffthis<cr>`             | `gitsigns.nvim` |  |
| `<leader>gg` | n | Open Neogit                                                                      | `<cmd>Neogit<CR>`                        | `neogit` |  |
| `<leader>gp` | n | Gitsigns: preview hunk                                                           | `<cmd>Gitsigns preview_hunk<cr>`         | `gitsigns.nvim` |  |
| `<leader>gs` | n | Gitsigns: stage hunk                                                             | `<cmd>Gitsigns stage_hunk<cr>`           | `gitsigns.nvim` |  |
| `<leader>gu` | n | Gitsigns: undo stage hunk                                                        | `<cmd>Gitsigns undo_stage_hunk<cr>`      | `gitsigns.nvim` |  |
| `<S-Tab>` | n | Diffview: open diff for previous file                                            | `previous file diff`                     | `diffview.nvim` | 🔸 |
| `<Tab>` | n | Diffview: open diff for next file                                                | `next file diff`                         | `diffview.nvim` | 🔸 |
| `gf` | n | Diffview: open local file in a tabpage                                           | `goto_file`                              | `diffview.nvim` | 🔸 |
| `S` | n | Diffview file panel: stage all entries                                           | `stage all (file panel)`                 | `diffview.nvim` | 🔸 |
| `U` | n | Diffview file panel: unstage all entries                                         | `unstage all (file panel)`               | `diffview.nvim` | 🔸 |
| `X` | n | Diffview file panel: revert file to left state                                   | `restore entry (file panel)`             | `diffview.nvim` | 🔸 |
| `[x` | n | Diffview merge: jump to previous conflict                                        | `previous conflict`                      | `diffview.nvim` | 🔸 |
| `]x` | n | Diffview merge: jump to next conflict                                            | `next conflict`                          | `diffview.nvim` | 🔸 |

### Harpoon <a id="group-harpoon"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<A-1>` | n | Harpoon: go to file 1                                                            | `harpoon.ui.nav_file(1)`                 | `harpoon` |  |
| `<A-2>` | n | Harpoon: go to file 2                                                            | `harpoon.ui.nav_file(2)`                 | `harpoon` |  |
| `<A-3>` | n | Harpoon: go to file 3                                                            | `harpoon.ui.nav_file(3)`                 | `harpoon` |  |
| `<A-4>` | n | Harpoon: go to file 4                                                            | `harpoon.ui.nav_file(4)`                 | `harpoon` |  |
| `<A-5>` | n | Harpoon: go to file 5                                                            | `harpoon.ui.nav_file(5)`                 | `harpoon` |  |
| `<A-6>` | n | Harpoon: go to file 6                                                            | `harpoon.ui.nav_file(6)`                 | `harpoon` |  |
| `<A-7>` | n | Harpoon: go to file 7                                                            | `harpoon.ui.nav_file(7)`                 | `harpoon` |  |
| `<A-8>` | n | Harpoon: go to file 8                                                            | `harpoon.ui.nav_file(8)`                 | `harpoon` |  |
| `<A-9>` | n | Harpoon: go to file 9                                                            | `harpoon.ui.nav_file(9)`                 | `harpoon` |  |
| `<leader>ha` | n | Harpoon: add current file                                                        | `harpoon.mark.add_file`                  | `harpoon` |  |
| `<leader>hh` | n | Harpoon: toggle quick menu                                                       | `harpoon.ui.toggle_quick_menu`           | `harpoon` |  |

### Help <a id="group-help"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<leader>?` | n | Show all keymaps (which-key)                                                     | `require('which-key').show({ global = tr…` | `which-key.nvim` |  |

### Insert <a id="group-insert"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-a>` | i | Insert previously inserted text                                                  | `(edit)`                                 | _core_ | 🔹 |
| `<C-d>` | i | Un-indent current line                                                           | `(edit)`                                 | _core_ | 🔹 |
| `<C-o>` | i | Execute one Normal-mode command                                                  | `(edit)`                                 | _core_ | 🔹 |
| `<C-r>` | i | Insert contents of a register                                                    | `(edit)`                                 | _core_ | 🔹 |
| `<C-t>` | i | Indent current line                                                              | `(edit)`                                 | _core_ | 🔹 |
| `<C-u>` | i | Delete to start of line                                                          | `(edit)`                                 | _core_ | 🔹 |
| `<C-w>` | i | Delete word before cursor                                                        | `(edit)`                                 | _core_ | 🔹 |

### LSP <a id="group-lsp"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-s>` | i | LSP: signature help                                                              | `vim.lsp.buf.signature_help`             | `nvim-lspconfig` |  |
| `<leader>la` | n | LSP: code action (Lspsaga)                                                       | `:Lspsaga code_action<CR>`               | `lspsaga.nvim` |  |
| `<leader>lc` | n | LSP: run CodeLens action                                                         | `vim.lsp.codelens.run`                   | `nvim-lspconfig` |  |
| `<leader>lr` | n | LSP: rename symbol                                                               | `vim.lsp.buf.rename`                     | `nvim-lspconfig` |  |
| `<leader>lSr` | n | LSP: restart                                                                     | `<cmd>lsp restart<CR>`                   | `nvim-lspconfig` |  |
| `gD` | n | LSP: go to declaration                                                           | `vim.lsp.buf.declaration`                | `nvim-lspconfig` |  |
| `gd` | n | LSP: definitions (Telescope)                                                     | `<cmd>Telescope lsp_definitions<CR>`     | `nvim-lspconfig` |  |
| `gi` | n | LSP: implementations (Telescope)                                                 | `<cmd>Telescope lsp_implementations<CR>` | `nvim-lspconfig` |  |
| `gR` | n | LSP: references (Telescope)                                                      | `<cmd>Telescope lsp_references<CR>`      | `nvim-lspconfig` |  |
| `gt` | n | LSP: type definitions (Telescope)                                                | `<cmd>Telescope lsp_type_implementations…` | `nvim-lspconfig` |  |
| `K` | n | LSP: hover documentation                                                         | `vim.lsp.buf.hover`                      | `nvim-lspconfig` |  |

### Marks & Jumps <a id="group-marks--jumps"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `'{mark}` | n,x,o | To first non-blank of marked line                                                | `(motion)`                               | _core_ | 🔹 |
| `<C-i>` | n | Jump to newer position in jumplist                                               | `(jump)`                                 | _core_ | 🔹 |
| `<C-o>` | n | Jump to older position in jumplist                                               | `(jump)`                                 | _core_ | 🔹 |
| `<C-t>` | n | Jump back from tag                                                               | `(jump)`                                 | _core_ | 🔹 |
| `<C-]>` | n | Jump to definition/tag under cursor                                              | `(jump)`                                 | _core_ | 🔹 |
| `g,` | n | Go to newer position in change list                                              | `(jump)`                                 | _core_ | 🔹 |
| `g;` | n | Go to older position in change list                                              | `(jump)`                                 | _core_ | 🔹 |
| `gf` | n | Go to file under cursor                                                          | `(jump)`                                 | _core_ | 🔹 |
| `m{a-zA-Z}` | n | Set mark at cursor                                                               | `(mark)`                                 | _core_ | 🔹 |

### Misc <a id="group-misc"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-g>` | n | Show file name and status                                                        | `(misc)`                                 | _core_ | 🔹 |
| `<C-l>` | n | Redraw screen                                                                    | `(misc)`                                 | _core_ | 🔹 |
| `<leader><leader>sn` | n | Show notification history                                                        | `Snacks.notifier.show_history()`         | `snacks.nvim` |  |
| `<leader>L` | n | Open Lazy plugin manager                                                         | `<cmd>Lazy<CR>`                          | _core_ |  |
| `ga` | n | Show character codes under cursor                                                | `(misc)`                                 | _core_ | 🔹 |
| `ZQ` | n | Quit without writing                                                             | `(misc)`                                 | _core_ | 🔹 |
| `ZZ` | n | Write file and quit                                                              | `(misc)`                                 | _core_ | 🔹 |

### Motion <a id="group-motion"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `$` | n,x,o | To end of line                                                                   | `(motion)`                               | _core_ | 🔹 |
| `%` | n,x,o | To matching bracket/pair                                                         | `(motion)`                               | _core_ | 🔹 |
| `(` | n,x,o | Backward one sentence                                                            | `(motion)`                               | _core_ | 🔹 |
| `)` | n,x,o | Forward one sentence                                                             | `(motion)`                               | _core_ | 🔹 |
| `+` | n,x,o | Down to first non-blank of next line                                             | `(motion)`                               | _core_ | 🔹 |
| `,` | n,x,o | Repeat last f/F/t/T reversed                                                     | `(motion)`                               | _core_ | 🔹 |
| `0` | n,x,o | To first column of line                                                          | `(motion)`                               | _core_ | 🔹 |
| `;` | n,x,o | Repeat last f/F/t/T                                                              | `(motion)`                               | _core_ | 🔹 |
| `b` | n,x,o | Back to start of word                                                            | `(motion)`                               | _core_ | 🔹 |
| `B` | n,x,o | Back to start of WORD                                                            | `(motion)`                               | _core_ | 🔹 |
| `e` | n,x,o | Forward to end of word                                                           | `(motion)`                               | _core_ | 🔹 |
| `E` | n,x,o | Forward to end of WORD                                                           | `(motion)`                               | _core_ | 🔹 |
| `f{char}` | n,x,o | To next occurrence of {char}                                                     | `(motion)`                               | _core_ | 🔹 |
| `F{char}` | n,x,o | To previous occurrence of {char}                                                 | `(motion)`                               | _core_ | 🔹 |
| `G` | n,x,o | To last line (or line [count])                                                   | `(motion)`                               | _core_ | 🔹 |
| `ge` | n,x,o | Back to end of previous word                                                     | `(motion)`                               | _core_ | 🔹 |
| `gE` | n,x,o | Back to end of previous WORD                                                     | `(motion)`                               | _core_ | 🔹 |
| `gg` | n,x,o | To first line (or line [count])                                                  | `(motion)`                               | _core_ | 🔹 |
| `g_` | n,x,o | To last non-blank character of line                                              | `(motion)`                               | _core_ | 🔹 |
| `h` | n,x,o | Left one character                                                               | `(motion)`                               | _core_ | 🔹 |
| `H` | n,x,o | To top of window                                                                 | `(motion)`                               | _core_ | 🔹 |
| `j` | n,x,o | Down one line                                                                    | `(motion)`                               | _core_ | 🔹 |
| `k` | n,x,o | Up one line                                                                      | `(motion)`                               | _core_ | 🔹 |
| `l` | n,x,o | Right one character                                                              | `(motion)`                               | _core_ | 🔹 |
| `L` | n,x,o | To bottom of window                                                              | `(motion)`                               | _core_ | 🔹 |
| `M` | n,x,o | To middle of window                                                              | `(motion)`                               | _core_ | 🔹 |
| `t{char}` | n,x,o | Till before next {char}                                                          | `(motion)`                               | _core_ | 🔹 |
| `T{char}` | n,x,o | Till after previous {char}                                                       | `(motion)`                               | _core_ | 🔹 |
| `w` | n,x,o | Forward to start of next word                                                    | `(motion)`                               | _core_ | 🔹 |
| `W` | n,x,o | Forward to start of next WORD                                                    | `(motion)`                               | _core_ | 🔹 |
| `[[` | n,x,o | Backward to section/'{' in column 1                                              | `(motion)`                               | _core_ | 🔹 |
| `]]` | n,x,o | Forward to section/'{' in column 1                                               | `(motion)`                               | _core_ | 🔹 |
| `^` | n,x,o | To first non-blank character of line                                             | `(motion)`                               | _core_ | 🔹 |
| `{` | n,x,o | Backward one paragraph                                                           | `(motion)`                               | _core_ | 🔹 |
| `\|` | n,x,o | To column [count]                                                                | `(motion)`                               | _core_ | 🔹 |
| `}` | n,x,o | Forward one paragraph                                                            | `(motion)`                               | _core_ | 🔹 |

### Navigation <a id="group-navigation"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<c-h>` | n | Navigate to left pane/split                                                      | `<cmd>TmuxNavigateLeft<cr>`              | `vim-tmux-navigator` |  |
| `<c-j>` | n | Navigate to lower pane/split                                                     | `<cmd>TmuxNavigateDown<cr>`              | `vim-tmux-navigator` |  |
| `<c-k>` | n | Navigate to upper pane/split                                                     | `<cmd>TmuxNavigateUp<cr>`                | `vim-tmux-navigator` |  |
| `<c-l>` | n | Navigate to right pane/split                                                     | `<cmd>TmuxNavigateRight<cr>`             | `vim-tmux-navigator` |  |
| `<c-\>` | n | Navigate to previous pane/split                                                  | `<cmd>TmuxNavigatePrevious<cr>`          | `vim-tmux-navigator` |  |
| `gj` | n | History: go back                                                                 | `<cmd>HisTravBack<cr>`                   | `history-traverse` |  |
| `gk` | n | History: go forward                                                              | `<cmd>HisTravForward<cr>`                | `history-traverse` |  |

### Operators <a id="group-operators"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `g=` | n | mini.operators: evaluate text and replace with result                            | `evaluate (motion)`                      | `mini.operators` | 🔸 |
| `g=` | x | mini.operators: evaluate selection                                               | `evaluate (selection)`                   | `mini.operators` | 🔸 |
| `g==` | n | mini.operators: evaluate current line                                            | `evaluate (line)`                        | `mini.operators` | 🔸 |
| `gm` | n | mini.operators: duplicate text over motion                                       | `multiply (motion)`                      | `mini.operators` | 🔸 |
| `gm` | x | mini.operators: duplicate selection                                              | `multiply (selection)`                   | `mini.operators` | 🔸 |
| `gmm` | n | mini.operators: duplicate current line                                           | `multiply (line)`                        | `mini.operators` | 🔸 |
| `gr` | n | mini.operators: replace text with register                                       | `replace w/ register (motion)`           | `mini.operators` | 🔸 |
| `gr` | x | mini.operators: replace selection with register                                  | `replace w/ register (selection)`        | `mini.operators` | 🔸 |
| `grr` | n | mini.operators: replace line with register                                       | `replace w/ register (line)`             | `mini.operators` | 🔸 |
| `gs` | n | mini.operators: sort text over motion                                            | `sort (motion)`                          | `mini.operators` | 🔸 |
| `gs` | x | mini.operators: sort selection                                                   | `sort (selection)`                       | `mini.operators` | 🔸 |
| `gss` | n | mini.operators: sort current line                                                | `sort (line)`                            | `mini.operators` | 🔸 |
| `gx` | n | mini.operators: exchange region (2-step swap)                                    | `exchange (motion)`                      | `mini.operators` | 🔸 |
| `gx` | x | mini.operators: exchange selection                                               | `exchange (selection)`                   | `mini.operators` | 🔸 |
| `gxx` | n | mini.operators: exchange current line                                            | `exchange (line)`                        | `mini.operators` | 🔸 |

### Registers & Macros <a id="group-registers--macros"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `"{reg}` | n,x | Use register for next yank/delete/paste                                          | `(register)`                             | _core_ | 🔹 |
| `@@` | n | Repeat last played macro                                                         | `(macro)`                                | _core_ | 🔹 |
| `@{reg}` | n | Play back macro from register                                                    | `(macro)`                                | _core_ | 🔹 |
| `q{a-z}` | n | Record macro into register                                                       | `(macro)`                                | _core_ | 🔹 |

### Scrolling <a id="group-scrolling"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-b>` | n | Scroll up one full screen                                                        | `(scroll)`                               | _core_ | 🔹 |
| `<C-d>` | n | Scroll down half a screen                                                        | `(scroll)`                               | _core_ | 🔹 |
| `<C-e>` | n | Scroll down one line                                                             | `(scroll)`                               | _core_ | 🔹 |
| `<C-f>` | n | Scroll down one full screen                                                      | `(scroll)`                               | _core_ | 🔹 |
| `<C-u>` | n | Scroll up half a screen                                                          | `(scroll)`                               | _core_ | 🔹 |
| `<C-y>` | n | Scroll up one line                                                               | `(scroll)`                               | _core_ | 🔹 |
| `zb` | n | Scroll current line to bottom                                                    | `(scroll)`                               | _core_ | 🔹 |
| `zt` | n | Scroll current line to top                                                       | `(scroll)`                               | _core_ | 🔹 |
| `zz` | n | Center current line in window                                                    | `(scroll)`                               | _core_ | 🔹 |

### Search <a id="group-search"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `#` | n,x,o | Search backward for word under cursor                                            | `(search)`                               | _core_ | 🔹 |
| `*` | n,x,o | Search forward for word under cursor                                             | `(search)`                               | _core_ | 🔹 |
| `,` | n,x,o | Flash: repeat last char motion, opposite direction                               | `repeat f/t/F/T (opposite dir)`          | `flash.nvim` | 🔸 |
| `/` | n,x,o | Search forward                                                                   | `(search)`                               | _core_ | 🔹 |
| `;` | n,x,o | Flash: repeat last char motion, same direction                                   | `repeat f/t/F/T (same dir)`              | `flash.nvim` | 🔸 |
| `<c-s>` | c | Toggle flash while searching                                                     | `require('flash').toggle()`              | `flash.nvim` |  |
| `<ESC>` | n | Clear search highlight                                                           | `:nohlsearch\|:echo<CR>`                 | _core_ |  |
| `<F17>` | n,x,o | Flash jump                                                                       | `require('flash').jump()`                | `flash.nvim` |  |
| `<F18>` | n,x,o | Flash treesitter                                                                 | `require('flash').treesitter()`          | `flash.nvim` |  |
| `<k7>` | n,x,o | Flash jump                                                                       | `require('flash').jump()`                | `flash.nvim` |  |
| `?` | n,x,o | Search backward                                                                  | `(search)`                               | _core_ | 🔹 |
| `f` | n,x,o | Flash: enhanced f, jump to char (dot-repeat)                                     | `enhanced f (flash char)`                | `flash.nvim` | 🔸 |
| `F` | n,x,o | Flash: enhanced F, backward jump to char                                         | `enhanced F (flash char back)`           | `flash.nvim` | 🔸 |
| `g#` | n,x,o | Search backward for partial word under cursor                                    | `(search)`                               | _core_ | 🔹 |
| `g*` | n,x,o | Search forward for partial word under cursor                                     | `(search)`                               | _core_ | 🔹 |
| `n` | n,x,o | Repeat last search                                                               | `(search)`                               | _core_ | 🔹 |
| `N` | n,x,o | Repeat last search, opposite direction                                           | `(search)`                               | _core_ | 🔹 |
| `r` | o | Remote flash (operator pending)                                                  | `require('flash').remote()`              | `flash.nvim` |  |
| `R` | o,x | Treesitter search                                                                | `require('flash').treesitter_search()`   | `flash.nvim` |  |
| `s` | n | Flash jump                                                                       | `require('flash').jump()`                | `flash.nvim` |  |
| `t` | n,x,o | Flash: enhanced t, jump till char                                                | `enhanced t (flash till)`                | `flash.nvim` | 🔸 |
| `T` | n,x,o | Flash: enhanced T, backward jump till char                                       | `enhanced T (flash till back)`           | `flash.nvim` | 🔸 |

### Surround <a id="group-surround"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-g>s` | i | Surround: add pair around the cursor                                             | `surround at cursor`                     | `nvim-surround` | 🔸 |
| `<C-g>S` | i | Surround: add pair around cursor, on new lines                                   | `surround at cursor (new lines)`         | `nvim-surround` | 🔸 |
| `cS` | n | Surround: change a pair onto new lines                                           | `change surround (new lines)`            | `nvim-surround` | 🔸 |
| `cs{target}{replacement}` | n | Surround: change a surrounding pair                                              | `change surround`                        | `nvim-surround` | 🔸 |
| `ds{char}` | n | Surround: delete a surrounding pair                                              | `delete surround`                        | `nvim-surround` | 🔸 |
| `gS` | x | Surround: add pair around selection, on new lines                                | `surround selection (new lines)`         | `nvim-surround` | 🔸 |
| `S` | x | Surround: add pair around visual selection                                       | `surround selection`                     | `nvim-surround` | 🔸 |
| `yS` | n | Surround: add pair around motion, on new lines                                   | `add surround around motion (new lines)` | `nvim-surround` | 🔸 |
| `yss` | n | Surround: add pair around current line                                           | `add surround around line`               | `nvim-surround` | 🔸 |
| `ySS` | n | Surround: add pair around line, on new lines                                     | `add surround around line (new lines)`   | `nvim-surround` | 🔸 |
| `ys{motion}{char}` | n | Surround: add pair around a motion                                               | `add surround around motion`             | `nvim-surround` | 🔸 |

### Tabs <a id="group-tabs"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<leader><S-Tab>` | n | Go to previous tab                                                               | `<cmd>tabp<CR>`                          | _core_ |  |
| `<leader><Tab>` | n | Go to next tab                                                                   | `<cmd>tabn<CR>`                          | _core_ |  |
| `<leader>tf` | n | Open current file in new tab                                                     | `<cmd>tabnew %<CR>`                      | _core_ |  |
| `<leader>tn` | n | Go to next tab                                                                   | `<cmd>tabn<CR>`                          | _core_ |  |
| `<leader>to` | n | Open new tab                                                                     | `<cmd>tabnew<CR>`                        | _core_ |  |
| `<leader>tp` | n | Go to previous tab                                                               | `<cmd>tabp<CR>`                          | _core_ |  |
| `<leader>tq` | n | Close current tab                                                                | `<cmd>tabclose<CR>`                      | _core_ |  |
| `gT` | n | Go to previous tab page                                                          | `(tab)`                                  | _core_ | 🔹 |

### Terminal <a id="group-terminal"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<Esc>` | t | Exit terminal insert mode                                                        | `<C-\><C-N>`                             | _core_ |  |

### Text Objects <a id="group-text-objects"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<A-v>` | n | Incremental selection: start / expand node                                       | `init_selection`                         | `nvim-treesitter` |  |
| `<A-v>` | x | Incremental selection: expand to next node                                       | `node_incremental`                       | `nvim-treesitter` |  |
| `<A-V>` | x | Incremental selection: shrink node                                               | `node_decremental`                       | `nvim-treesitter` |  |
| `<end>` | n,x,o | Repeat last textobject move forward                                              | `repeat_last_move (forward)`             | `nvim-treesitter` |  |
| `<home>` | n,x,o | Repeat last textobject move backward                                             | `repeat_last_move (backward)`            | `nvim-treesitter` |  |
| `<leader>a` | n | Swap parameter with next                                                         | `swap_next @parameter.inner`             | `nvim-treesitter` |  |
| `<leader>A` | n | Swap parameter with previous                                                     | `swap_previous @parameter.inner`         | `nvim-treesitter` |  |
| `==` | x,o | Textobject: assignment (outer)                                                   | `@assignment.outer`                      | `nvim-treesitter` |  |
| `=l` | x,o | Textobject: assignment left-hand side                                            | `@assignment.lhs`                        | `nvim-treesitter` |  |
| `=r` | x,o | Textobject: assignment right-hand side                                           | `@assignment.rhs`                        | `nvim-treesitter` |  |
| `aa` | x,o | Textobject: parameter (outer)                                                    | `@parameter.outer`                       | `nvim-treesitter` |  |
| `ab` | x,o | Textobject: block (outer)                                                        | `@block.outer`                           | `nvim-treesitter` |  |
| `ac` | x,o | Textobject: comment (outer)                                                      | `@comment.outer`                         | `nvim-treesitter` |  |
| `af` | x,o | Textobject: call (outer)                                                         | `@call.outer`                            | `nvim-treesitter` |  |
| `ai` | x,o | Textobject: conditional (outer)                                                  | `@conditional.outer`                     | `nvim-treesitter` |  |
| `al` | x,o | Textobject: loop (outer)                                                         | `@loop.outer`                            | `nvim-treesitter` |  |
| `am` | x,o | Textobject: function (outer)                                                     | `@function.outer`                        | `nvim-treesitter` |  |
| `an` | x,o | Textobject: number (inner)                                                       | `@number.inner`                          | `nvim-treesitter` |  |
| `ar` | x,o | Textobject: return (outer)                                                       | `@return.outer`                          | `nvim-treesitter` |  |
| `at` | x,o | Textobject: class (outer)                                                        | `@class.outer`                           | `nvim-treesitter` |  |
| `a{id}` | x,o | mini.ai: select 'around' textobject {id}                                         | `select around textobject`               | `mini.ai` | 🔸 |
| `g[` | n,x,o | mini.ai: move to left edge of nearest textobject                                 | `go to left edge of textobject`          | `mini.ai` | 🔸 |
| `g]` | n,x,o | mini.ai: move to right edge of nearest textobject                                | `go to right edge of textobject`         | `mini.ai` | 🔸 |
| `ia` | x,o | Textobject: parameter (inner)                                                    | `@parameter.inner`                       | `nvim-treesitter` |  |
| `ib` | x,o | Textobject: block (inner)                                                        | `@block.inner`                           | `nvim-treesitter` |  |
| `ic` | x,o | Textobject: comment (outer)                                                      | `@comment.outer`                         | `nvim-treesitter` |  |
| `if` | x,o | Textobject: call (inner)                                                         | `@call.inner`                            | `nvim-treesitter` |  |
| `ii` | x,o | Textobject: conditional (inner)                                                  | `@conditional.inner`                     | `nvim-treesitter` |  |
| `il` | x,o | Textobject: loop (inner)                                                         | `@loop.inner`                            | `nvim-treesitter` |  |
| `im` | x,o | Textobject: function (inner)                                                     | `@function.inner`                        | `nvim-treesitter` |  |
| `in` | x,o | Textobject: number (inner)                                                       | `@number.inner`                          | `nvim-treesitter` |  |
| `ir` | x,o | Textobject: return (inner)                                                       | `@return.inner`                          | `nvim-treesitter` |  |
| `it` | x,o | Textobject: class (inner)                                                        | `@class.inner`                           | `nvim-treesitter` |  |
| `i{id}` | x,o | mini.ai: select 'inside' textobject {id}                                         | `select inside textobject`               | `mini.ai` | 🔸 |

### Treewalker Hydra <a id="group-treewalker-hydra"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `++` | hydra(treewalker) | Previous assignment (outer) (alias of =+)                                        | `goto_previous_start @assignment.outer`  | `hydra.nvim` |  |
| `+L` | hydra(treewalker) | Previous assignment (lhs) (alias of =L)                                          | `goto_previous_start @assignment.lhs`    | `hydra.nvim` |  |
| `+R` | hydra(treewalker) | Previous assignment (rhs) (alias of =R)                                          | `goto_previous_start @assignment.rhs`    | `hydra.nvim` |  |
| `=+` | hydra(treewalker) | Previous assignment (outer)                                                      | `goto_previous_start @assignment.outer`  | `hydra.nvim` |  |
| `==` | hydra(treewalker) | Next assignment (outer)                                                          | `goto_next_start @assignment.outer`      | `hydra.nvim` |  |
| `=l` | hydra(treewalker) | Next assignment (lhs)                                                            | `goto_next_start @assignment.lhs`        | `hydra.nvim` |  |
| `=L` | hydra(treewalker) | Previous assignment (lhs)                                                        | `goto_previous_start @assignment.lhs`    | `hydra.nvim` |  |
| `=r` | hydra(treewalker) | Next assignment (rhs)                                                            | `goto_next_start @assignment.rhs`        | `hydra.nvim` |  |
| `=R` | hydra(treewalker) | Previous assignment (rhs)                                                        | `goto_previous_start @assignment.rhs`    | `hydra.nvim` |  |
| `a` | hydra(treewalker) | Next parameter (outer)                                                           | `goto_next_start @parameter.outer`       | `hydra.nvim` |  |
| `A` | hydra(treewalker) | Previous parameter (outer)                                                       | `goto_previous_start @parameter.outer`   | `hydra.nvim` |  |
| `b` | hydra(treewalker) | Next block (outer)                                                               | `goto_next_start @block.outer`           | `hydra.nvim` |  |
| `B` | hydra(treewalker) | Previous block (outer)                                                           | `goto_previous_start @block.outer`       | `hydra.nvim` |  |
| `c` | hydra(treewalker) | Next comment (outer)                                                             | `goto_next_start @comment.outer`         | `hydra.nvim` |  |
| `C` | hydra(treewalker) | Previous comment (outer)                                                         | `goto_previous_start @comment.outer`     | `hydra.nvim` |  |
| `f` | hydra(treewalker) | Next call (outer)                                                                | `goto_next_start @call.outer`            | `hydra.nvim` |  |
| `F` | hydra(treewalker) | Previous call (outer)                                                            | `goto_previous_start @call.outer`        | `hydra.nvim` |  |
| `h` | hydra(treewalker) | Move left / ascend                                                               | `<cmd>Treewalker Left<cr>`               | `hydra.nvim` |  |
| `i` | hydra(treewalker) | Next conditional (outer)                                                         | `goto_next_start @conditional.outer`     | `hydra.nvim` |  |
| `I` | hydra(treewalker) | Previous conditional (outer)                                                     | `goto_previous_start @conditional.outer` | `hydra.nvim` |  |
| `j` | hydra(treewalker) | Move down a sibling node                                                         | `<cmd>Treewalker Down<cr>`               | `hydra.nvim` |  |
| `k` | hydra(treewalker) | Move up a sibling node                                                           | `<cmd>Treewalker Up<cr>`                 | `hydra.nvim` |  |
| `l` | hydra(treewalker) | Move right / descend                                                             | `<cmd>Treewalker Right<cr>`              | `hydra.nvim` |  |
| `m` | hydra(treewalker) | Next function (outer)                                                            | `goto_next_start @function.outer`        | `hydra.nvim` |  |
| `M` | hydra(treewalker) | Previous function (outer)                                                        | `goto_previous_start @function.outer`    | `hydra.nvim` |  |
| `n` | hydra(treewalker) | Next number (inner)                                                              | `goto_next_start @number.inner`          | `hydra.nvim` |  |
| `N` | hydra(treewalker) | Previous number (inner)                                                          | `goto_previous_start @number.inner`      | `hydra.nvim` |  |
| `o` | hydra(treewalker) | Next conditional (inner)                                                         | `goto_next_start @conditional.inner`     | `hydra.nvim` |  |
| `O` | hydra(treewalker) | Previous conditional (inner)                                                     | `goto_previous_start @conditional.inner` | `hydra.nvim` |  |
| `p` | hydra(treewalker) | Next parameter (inner)                                                           | `goto_next_start @parameter.inner`       | `hydra.nvim` |  |
| `P` | hydra(treewalker) | Previous parameter (inner)                                                       | `goto_previous_start @parameter.inner`   | `hydra.nvim` |  |
| `r` | hydra(treewalker) | Next return (outer)                                                              | `goto_next_start @return.outer`          | `hydra.nvim` |  |
| `R` | hydra(treewalker) | Previous return (outer)                                                          | `goto_previous_start @return.outer`      | `hydra.nvim` |  |
| `S` | n → hydra(treewalker) | Enter the pink hydra "treewalker" (also unbinds the default S)                   | `enter hydra`                            | `hydra.nvim` |  |
| `t` | hydra(treewalker) | Next class (outer)                                                               | `goto_next_start @class.outer`           | `hydra.nvim` |  |
| `T` | hydra(treewalker) | Previous class (outer)                                                           | `goto_previous_start @class.outer`       | `hydra.nvim` |  |
| `v` | hydra(treewalker) | Next block (outer)                                                               | `goto_next_start @block.outer`           | `hydra.nvim` |  |
| `V` | hydra(treewalker) | Previous block (inner)                                                           | `goto_previous_start @block.inner`       | `hydra.nvim` |  |
| `w` | hydra(treewalker) | Next loop (outer)                                                                | `goto_next_start @loop.outer`            | `hydra.nvim` |  |
| `W` | hydra(treewalker) | Previous loop (outer)                                                            | `goto_previous_start @loop.outer`        | `hydra.nvim` |  |

### Visual <a id="group-visual"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-v>` | n | Start blockwise Visual mode                                                      | `(visual)`                               | _core_ | 🔹 |
| `A` | x | Append at end of block (blockwise)                                               | `(edit)`                                 | _core_ | 🔹 |
| `I` | x | Insert at start of block (blockwise)                                             | `(edit)`                                 | _core_ | 🔹 |
| `o` | x | Move to other end of selection                                                   | `(visual)`                               | _core_ | 🔹 |
| `O` | x | Move to other corner (blockwise)                                                 | `(visual)`                               | _core_ | 🔹 |
| `u` | x | Lowercase selection                                                              | `(edit)`                                 | _core_ | 🔹 |
| `U` | x | Uppercase selection                                                              | `(edit)`                                 | _core_ | 🔹 |
| `v` | n | Start charwise Visual mode                                                       | `(visual)`                               | _core_ | 🔹 |
| `V` | n | Start linewise Visual mode                                                       | `(visual)`                               | _core_ | 🔹 |

### Windows <a id="group-windows"></a>

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `<C-Down>` | n | Decrease split height                                                            | `:resize -1<CR>`                         | _core_ |  |
| `<C-Left>` | n | Increase vertical split width                                                    | `:vertical resize +1<CR>`                | _core_ |  |
| `<C-Right>` | n | Decrease vertical split width                                                    | `:vertical resize -1<CR>`                | _core_ |  |
| `<C-Up>` | n | Increase split height                                                            | `:resize +1<CR>`                         | _core_ |  |
| `<C-w>=` | n | Equalize window sizes                                                            | `(window)`                               | _core_ | 🔹 |
| `<C-w>h` | n | Move to window on the left                                                       | `(window)`                               | _core_ | 🔹 |
| `<C-w>j` | n | Move to window below                                                             | `(window)`                               | _core_ | 🔹 |
| `<C-w>k` | n | Move to window above                                                             | `(window)`                               | _core_ | 🔹 |
| `<C-w>l` | n | Move to window on the right                                                      | `(window)`                               | _core_ | 🔹 |
| `<C-w>o` | n | Close all other windows                                                          | `(window)`                               | _core_ | 🔹 |
| `<C-w>q` | n | Quit current window                                                              | `(window)`                               | _core_ | 🔹 |
| `<C-w>s` | n | Split window horizontally                                                        | `(window)`                               | _core_ | 🔹 |
| `<C-w>v` | n | Split window vertically                                                          | `(window)`                               | _core_ | 🔹 |
| `<C-w>w` | n | Cycle to next window                                                             | `(window)`                               | _core_ | 🔹 |
| `<C-w>_` | n | Maximize window height                                                           | `(window)`                               | _core_ | 🔹 |
| `<C-w>\|` | n | Maximize window width                                                            | `(window)`                               | _core_ | 🔹 |
| `<leader>se` | n | Equalize split sizes                                                             | `<C-w>=`                                 | _core_ |  |
| `<leader>sh` | n | Split window horizontally                                                        | `<cmd>split<CR>`                         | _core_ |  |
| `<leader>sm` | n | Toggle split maximize                                                            | `<cmd>MaximizerToggle<CR>`               | `vim-maximizer` |  |
| `<leader>sq` | n | Close current split                                                              | `<cmd>close<CR>`                         | _core_ |  |
| `<leader>sv` | n | Split window vertically                                                          | `<cmd>vsplit<CR>`                        | _core_ |  |

## All Keybindings (sorted) <a id="sec-all"></a>

Every keybinding in one flat table, sorted by key then mode.

| Key | Mode | Description                                                                      | Action                                   | Plugin | Implicit |
| --- | --- | -------------------------------------------------------------------------------- | ---------------------------------------- | --- | --- |
| `"{reg}` | n,x | Use register for next yank/delete/paste                                          | `(register)`                             | _core_ | 🔹 |
| `#` | n,x,o | Search backward for word under cursor                                            | `(search)`                               | _core_ | 🔹 |
| `$` | n | Origami: unfold recursively on folded line, else $                               | `unfold recursively or normal $`         | `nvim-origami` | 🔸 |
| `$` | n,x,o | To end of line                                                                   | `(motion)`                               | _core_ | 🔹 |
| `%` | n,x,o | To matching bracket/pair                                                         | `(motion)`                               | _core_ | 🔹 |
| `'{mark}` | n,x,o | To first non-blank of marked line                                                | `(motion)`                               | _core_ | 🔹 |
| `(` | n,x,o | Backward one sentence                                                            | `(motion)`                               | _core_ | 🔹 |
| `)` | n,x,o | Forward one sentence                                                             | `(motion)`                               | _core_ | 🔹 |
| `*` | n,x,o | Search forward for word under cursor                                             | `(search)`                               | _core_ | 🔹 |
| `+` | n,x,o | Down to first non-blank of next line                                             | `(motion)`                               | _core_ | 🔹 |
| `++` | hydra(treewalker) | Previous assignment (outer) (alias of =+)                                        | `goto_previous_start @assignment.outer`  | `hydra.nvim` |  |
| `+L` | hydra(treewalker) | Previous assignment (lhs) (alias of =L)                                          | `goto_previous_start @assignment.lhs`    | `hydra.nvim` |  |
| `+R` | hydra(treewalker) | Previous assignment (rhs) (alias of =R)                                          | `goto_previous_start @assignment.rhs`    | `hydra.nvim` |  |
| `,` | n,x,o | Flash: repeat last char motion, opposite direction                               | `repeat f/t/F/T (opposite dir)`          | `flash.nvim` | 🔸 |
| `,` | n,x,o | Repeat last f/F/t/T reversed                                                     | `(motion)`                               | _core_ | 🔹 |
| `-` | n | Oil: go to parent directory                                                      | `actions.parent`                         | `oil.nvim` |  |
| `-` | n | Oil (default): go to parent directory                                            | `actions.parent`                         | `oil.nvim` | 🔸 |
| `-` | n | Diffview file panel: stage/unstage entry                                         | `stage/unstage entry (file panel)`       | `diffview.nvim` | 🔸 |
| `.` | n | Repeat last change                                                               | `(edit)`                                 | _core_ | 🔹 |
| `/` | n,x,o | Search forward                                                                   | `(search)`                               | _core_ | 🔹 |
| `0` | n,x,o | To first column of line                                                          | `(motion)`                               | _core_ | 🔹 |
| `:` | n,x | Enter Command-line (Ex) mode                                                     | `(command)`                              | _core_ | 🔹 |
| `;` | n,x,o | Flash: repeat last char motion, same direction                                   | `repeat f/t/F/T (same dir)`              | `flash.nvim` | 🔸 |
| `;` | n,x,o | Repeat last f/F/t/T                                                              | `(motion)`                               | _core_ | 🔹 |
| `<` | n | Indent line left                                                                 | `<<`                                     | _core_ |  |
| `<` | v | Indent left, keep selection                                                      | `<gv`                                    | _core_ |  |
| `<A-1>` | n | Harpoon: go to file 1                                                            | `harpoon.ui.nav_file(1)`                 | `harpoon` |  |
| `<A-2>` | n | Harpoon: go to file 2                                                            | `harpoon.ui.nav_file(2)`                 | `harpoon` |  |
| `<A-3>` | n | Harpoon: go to file 3                                                            | `harpoon.ui.nav_file(3)`                 | `harpoon` |  |
| `<A-4>` | n | Harpoon: go to file 4                                                            | `harpoon.ui.nav_file(4)`                 | `harpoon` |  |
| `<A-5>` | n | Harpoon: go to file 5                                                            | `harpoon.ui.nav_file(5)`                 | `harpoon` |  |
| `<A-6>` | n | Harpoon: go to file 6                                                            | `harpoon.ui.nav_file(6)`                 | `harpoon` |  |
| `<A-7>` | n | Harpoon: go to file 7                                                            | `harpoon.ui.nav_file(7)`                 | `harpoon` |  |
| `<A-8>` | n | Harpoon: go to file 8                                                            | `harpoon.ui.nav_file(8)`                 | `harpoon` |  |
| `<A-9>` | n | Harpoon: go to file 9                                                            | `harpoon.ui.nav_file(9)`                 | `harpoon` |  |
| `<A-v>` | n | Incremental selection: start / expand node                                       | `init_selection`                         | `nvim-treesitter` |  |
| `<A-v>` | x | Incremental selection: expand to next node                                       | `node_incremental`                       | `nvim-treesitter` |  |
| `<A-V>` | x | Incremental selection: shrink node                                               | `node_decremental`                       | `nvim-treesitter` |  |
| `<C-a>` | i | Insert previously inserted text                                                  | `(edit)`                                 | _core_ | 🔹 |
| `<C-b>` | i | Completion: scroll documentation up                                              | `scroll_documentation_up / fallback`     | `blink.cmp` |  |
| `<C-b>` | i | Completion: scroll documentation up                                              | `scroll docs up`                         | `blink.cmp` | 🔸 |
| `<C-b>` | n | Scroll up one full screen                                                        | `(scroll)`                               | _core_ | 🔹 |
| `<C-c>` | i | Telescope (default): close picker                                                | `close`                                  | `telescope.nvim` | 🔸 |
| `<C-c>` | n | Oil (default): close buffer                                                      | `actions.close`                          | `oil.nvim` | 🔸 |
| `<C-c>` | n,i | CodeCompanion chat: close buffer                                                 | `chat: close`                            | `codecompanion.nvim` | 🔸 |
| `<C-d>` | i | Un-indent current line                                                           | `(edit)`                                 | _core_ | 🔹 |
| `<C-d>` | i,n | Telescope (default): scroll preview down                                         | `preview_scrolling_down`                 | `telescope.nvim` | 🔸 |
| `<C-d>` | n | Scroll down half a screen                                                        | `(scroll)`                               | _core_ | 🔹 |
| `<C-Down>` | n | Decrease split height                                                            | `:resize -1<CR>`                         | _core_ |  |
| `<C-e>` | i | Completion: cancel / hide menu                                                   | `hide menu`                              | `blink.cmp` | 🔸 |
| `<C-e>` | n | Scroll down one line                                                             | `(scroll)`                               | _core_ | 🔹 |
| `<C-F14>` | n | Go to previous diagnostic                                                        | `:Lspsaga diagnostic_jump_prev<CR>`      | `lspsaga.nvim` |  |
| `<C-f>` | i | Completion: scroll documentation down                                            | `scroll_documentation_down / fallback`   | `blink.cmp` |  |
| `<C-f>` | i | Completion: scroll documentation down                                            | `scroll docs down`                       | `blink.cmp` | 🔸 |
| `<C-f>` | n | Scroll down one full screen                                                      | `(scroll)`                               | _core_ | 🔹 |
| `<C-g>` | n | Show file name and status                                                        | `(misc)`                                 | _core_ | 🔹 |
| `<C-g>s` | i | Surround: add pair around the cursor                                             | `surround at cursor`                     | `nvim-surround` | 🔸 |
| `<C-g>S` | i | Surround: add pair around cursor, on new lines                                   | `surround at cursor (new lines)`         | `nvim-surround` | 🔸 |
| `<c-h>` | n | Navigate to left pane/split                                                      | `<cmd>TmuxNavigateLeft<cr>`              | `vim-tmux-navigator` |  |
| `<C-h>` | n,v | Oil (default): open in horizontal split                                          | `actions.select horizontal`              | `oil.nvim` | 🔸 |
| `<C-i>` | n | Jump to newer position in jumplist                                               | `(jump)`                                 | _core_ | 🔹 |
| `<C-j>` | i | Telescope picker: move to next item                                              | `actions.move_selection_next`            | `telescope.nvim` |  |
| `<c-j>` | n | Navigate to lower pane/split                                                     | `<cmd>TmuxNavigateDown<cr>`              | `vim-tmux-navigator` |  |
| `<C-k>` | i | Telescope picker: move to previous item                                          | `actions.move_selection_previous`        | `telescope.nvim` |  |
| `<C-k>` | i | Completion: toggle signature help                                                | `toggle signature help`                  | `blink.cmp` | 🔸 |
| `<c-k>` | n | Navigate to upper pane/split                                                     | `<cmd>TmuxNavigateUp<cr>`                | `vim-tmux-navigator` |  |
| `<c-l>` | n | Navigate to right pane/split                                                     | `<cmd>TmuxNavigateRight<cr>`             | `vim-tmux-navigator` |  |
| `<C-l>` | n | Redraw screen                                                                    | `(misc)`                                 | _core_ | 🔹 |
| `<C-l>` | n,v | Oil (default): refresh buffer                                                    | `actions.refresh`                        | `oil.nvim` | 🔸 |
| `<C-Left>` | n | Increase vertical split width                                                    | `:vertical resize +1<CR>`                | _core_ |  |
| `<C-n>` | i | Completion: select next item                                                     | `select next`                            | `blink.cmp` | 🔸 |
| `<C-n>` | i | Telescope (default): next result                                                 | `move_selection_next`                    | `telescope.nvim` | 🔸 |
| `<C-o>` | i | Execute one Normal-mode command                                                  | `(edit)`                                 | _core_ | 🔹 |
| `<C-o>` | n | Jump to older position in jumplist                                               | `(jump)`                                 | _core_ | 🔹 |
| `<C-p>` | i | Completion: select previous item                                                 | `select previous`                        | `blink.cmp` | 🔸 |
| `<C-p>` | i | Telescope (default): previous result                                             | `move_selection_previous`                | `telescope.nvim` | 🔸 |
| `<C-p>` | n,v | Oil (default): preview entry                                                     | `actions.preview`                        | `oil.nvim` | 🔸 |
| `<C-q>` | i | Telescope picker: send selection to quickfix                                     | `send_selected_to_qflist + open_qflist`  | `telescope.nvim` |  |
| `<C-q>` | i,n | Telescope (default): send all to quickfix                                        | `send_to_qflist + open_qflist`           | `telescope.nvim` | 🔸 |
| `<C-r>` | i | Insert contents of a register                                                    | `(edit)`                                 | _core_ | 🔹 |
| `<C-r>` | n | Redo                                                                             | `(edit)`                                 | _core_ | 🔹 |
| `<C-Right>` | n | Decrease vertical split width                                                    | `:vertical resize -1<CR>`                | _core_ |  |
| `<c-s>` | c | Toggle flash while searching                                                     | `require('flash').toggle()`              | `flash.nvim` |  |
| `<C-s>` | i | LSP: signature help                                                              | `vim.lsp.buf.signature_help`             | `nvim-lspconfig` |  |
| `<C-s>` | n | Trouble window: jump in horizontal split                                         | `jump (horizontal split)`                | `trouble.nvim` | 🔸 |
| `<C-s>` | n,i | CodeCompanion chat: send message                                                 | `chat: send`                             | `codecompanion.nvim` | 🔸 |
| `<C-s>` | n,v | Oil (default): open in vertical split                                            | `actions.select vertical`                | `oil.nvim` | 🔸 |
| `<C-space>` | i | Completion: open menu or toggle docs                                             | `show / show_documentation / hide_docume…` | `blink.cmp` |  |
| `<C-space>` | i | Completion: open menu or toggle docs                                             | `show menu / toggle docs`                | `blink.cmp` | 🔸 |
| `<C-t>` | i | Indent current line                                                              | `(edit)`                                 | _core_ | 🔹 |
| `<C-t>` | i,n | Telescope (default): open in new tab                                             | `select_tab`                             | `telescope.nvim` | 🔸 |
| `<C-t>` | n | Jump back from tag                                                               | `(jump)`                                 | _core_ | 🔹 |
| `<C-t>` | n,v | Oil (default): open in new tab                                                   | `actions.select tab`                     | `oil.nvim` | 🔸 |
| `<C-u>` | i | Delete to start of line                                                          | `(edit)`                                 | _core_ | 🔹 |
| `<C-u>` | i,n | Telescope (default): scroll preview up                                           | `preview_scrolling_up`                   | `telescope.nvim` | 🔸 |
| `<C-u>` | n | Scroll up half a screen                                                          | `(scroll)`                               | _core_ | 🔹 |
| `<C-Up>` | n | Increase split height                                                            | `:resize +1<CR>`                         | _core_ |  |
| `<C-v>` | i,n | Telescope (default): open in vertical split                                      | `select_vertical`                        | `telescope.nvim` | 🔸 |
| `<C-v>` | n | Trouble window: jump in vertical split                                           | `jump (vertical split)`                  | `trouble.nvim` | 🔸 |
| `<C-v>` | n | Start blockwise Visual mode                                                      | `(visual)`                               | _core_ | 🔹 |
| `<C-w>` | i | Delete word before cursor                                                        | `(edit)`                                 | _core_ | 🔹 |
| `<C-w>=` | n | Equalize window sizes                                                            | `(window)`                               | _core_ | 🔹 |
| `<C-w>h` | n | Move to window on the left                                                       | `(window)`                               | _core_ | 🔹 |
| `<C-w>j` | n | Move to window below                                                             | `(window)`                               | _core_ | 🔹 |
| `<C-w>k` | n | Move to window above                                                             | `(window)`                               | _core_ | 🔹 |
| `<C-w>l` | n | Move to window on the right                                                      | `(window)`                               | _core_ | 🔹 |
| `<C-w>o` | n | Close all other windows                                                          | `(window)`                               | _core_ | 🔹 |
| `<C-w>q` | n | Quit current window                                                              | `(window)`                               | _core_ | 🔹 |
| `<C-w>s` | n | Split window horizontally                                                        | `(window)`                               | _core_ | 🔹 |
| `<C-w>v` | n | Split window vertically                                                          | `(window)`                               | _core_ | 🔹 |
| `<C-w>w` | n | Cycle to next window                                                             | `(window)`                               | _core_ | 🔹 |
| `<C-w>_` | n | Maximize window height                                                           | `(window)`                               | _core_ | 🔹 |
| `<C-w>\|` | n | Maximize window width                                                            | `(window)`                               | _core_ | 🔹 |
| `<C-x>` | i,n | Telescope (default): open in horizontal split                                    | `select_horizontal`                      | `telescope.nvim` | 🔸 |
| `<C-y>` | i | Completion: accept selected item                                                 | `accept item`                            | `blink.cmp` | 🔸 |
| `<C-y>` | n | Scroll up one line                                                               | `(scroll)`                               | _core_ | 🔹 |
| `<c-\>` | n | Navigate to previous pane/split                                                  | `<cmd>TmuxNavigatePrevious<cr>`          | `vim-tmux-navigator` |  |
| `<C-]>` | i | Copilot: dismiss current suggestion                                              | `dismiss suggestion`                     | `copilot.lua` | 🔸 |
| `<C-]>` | n | Jump to definition/tag under cursor                                              | `(jump)`                                 | _core_ | 🔹 |
| `<C-_>` | i | CodeCompanion chat: open completion menu                                         | `chat: completion menu`                  | `codecompanion.nvim` | 🔸 |
| `<CR>` | i,n | Telescope (default): open selected entry                                         | `select_default`                         | `telescope.nvim` | 🔸 |
| `<CR>` | n | Oil: open entry                                                                  | `actions.select`                         | `oil.nvim` |  |
| `<CR>` | n | Copilot panel: accept suggestion under cursor                                    | `panel: accept`                          | `copilot.lua` | 🔸 |
| `<CR>` | n | CodeCompanion chat: send message                                                 | `chat: send`                             | `codecompanion.nvim` | 🔸 |
| `<CR>` | n | Trouble window: jump to item                                                     | `jump`                                   | `trouble.nvim` | 🔸 |
| `<CR>` | n,v | Oil (default): open entry                                                        | `actions.select`                         | `oil.nvim` | 🔸 |
| `<Down>` | i | Completion: select next item                                                     | `select next`                            | `blink.cmp` | 🔸 |
| `<Down>` | i | Telescope (default): next result                                                 | `move_selection_next`                    | `telescope.nvim` | 🔸 |
| `<end>` | n,x,o | Repeat last textobject move forward                                              | `repeat_last_move (forward)`             | `nvim-treesitter` |  |
| `<Esc>` | hydra(diagnostics) | Leave the hydra                                                                  | `exit hydra`                             | `hydra.nvim` |  |
| `<ESC>` | n | Clear search highlight                                                           | `:nohlsearch\|:echo<CR>`                 | _core_ |  |
| `<Esc>` | n | Telescope (default): close picker                                                | `close`                                  | `telescope.nvim` | 🔸 |
| `<Esc>` | t | Exit terminal insert mode                                                        | `<C-\><C-N>`                             | _core_ |  |
| `<F14>` | n | Go to next diagnostic                                                            | `:Lspsaga diagnostic_jump_next<CR>`      | `lspsaga.nvim` |  |
| `<F17>` | n,x,o | Flash jump                                                                       | `require('flash').jump()`                | `flash.nvim` |  |
| `<F18>` | n,x,o | Flash treesitter                                                                 | `require('flash').treesitter()`          | `flash.nvim` |  |
| `<F3>b` | n | Debug: toggle breakpoint                                                         | `dap.toggle_breakpoint`                  | `nvim-dap-ui` |  |
| `<F3>bd` | n | Debug: clear all breakpoints                                                     | `dap.clear_breakpoints`                  | `nvim-dap-ui` |  |
| `<F3>C` | n | Debug: run to cursor                                                             | `dap.run_to_cursor`                      | `nvim-dap-ui` |  |
| `<F3>cc` | n | Debug: continue                                                                  | `dap.continue`                           | `nvim-dap-ui` |  |
| `<F3>e` | n | Debug: evaluate expression                                                       | `dapui.eval`                             | `nvim-dap-ui` |  |
| `<F3>j` | n | Debug: go down a stack frame                                                     | `dap.down`                               | `nvim-dap-ui` |  |
| `<F3>k` | n | Debug: go up a stack frame                                                       | `dap.up`                                 | `nvim-dap-ui` |  |
| `<F3>q` | n | Debug: stop session                                                              | `dap.terminate`                          | `nvim-dap-ui` |  |
| `<F3>r` | n | Debug: toggle REPL                                                               | `dap.repl.toggle`                        | `nvim-dap-ui` |  |
| `<F3>uf` | n | Debug: toggle floating UI element                                                | `dapui.float_element`                    | `nvim-dap-ui` |  |
| `<F3>uu` | n | Debug: toggle UI                                                                 | `dapui.toggle`                           | `nvim-dap-ui` |  |
| `<F5>` | n | Debug: continue                                                                  | `dap.continue`                           | `nvim-dap-ui` |  |
| `<F6>` | n | Debug: step out                                                                  | `dap.step_out`                           | `nvim-dap-ui` |  |
| `<F7>` | n | Debug: step over                                                                 | `dap.step_over`                          | `nvim-dap-ui` |  |
| `<F8>` | n | Debug: run to cursor                                                             | `dap.run_to_cursor`                      | `nvim-dap-ui` |  |
| `<F9>` | n | Debug: step into                                                                 | `dap.step_into`                          | `nvim-dap-ui` |  |
| `<home>` | n,x,o | Repeat last textobject move backward                                             | `repeat_last_move (backward)`            | `nvim-treesitter` |  |
| `<k7>` | n,x,o | Flash jump                                                                       | `require('flash').jump()`                | `flash.nvim` |  |
| `<leader>+` | n | Increment number under cursor                                                    | `<C-a>`                                  | _core_ |  |
| `<leader>-` | n | Decrement number under cursor                                                    | `<C-x>`                                  | _core_ |  |
| `<leader><leader>sn` | n | Show notification history                                                        | `Snacks.notifier.show_history()`         | `snacks.nvim` |  |
| `<leader><S-Tab>` | n | Go to previous tab                                                               | `<cmd>tabp<CR>`                          | _core_ |  |
| `<leader><Tab>` | n | Go to next tab                                                                   | `<cmd>tabn<CR>`                          | _core_ |  |
| `<leader>?` | n | Show all keymaps (which-key)                                                     | `require('which-key').show({ global = tr…` | `which-key.nvim` |  |
| `<leader>a` | n | Swap parameter with next                                                         | `swap_next @parameter.inner`             | `nvim-treesitter` |  |
| `<leader>A` | n | Swap parameter with previous                                                     | `swap_previous @parameter.inner`         | `nvim-treesitter` |  |
| `<leader>b` | n | Diffview: toggle the file panel                                                  | `toggle file panel`                      | `diffview.nvim` | 🔸 |
| `<leader>c` | n | Change (yank into default register)                                              | `c`                                      | _core_ |  |
| `<leader>cb` | n | Diffview merge: choose BASE                                                      | `conflict: choose base`                  | `diffview.nvim` | 🔸 |
| `<leader>cd` | n | Open Diffview                                                                    | `:DiffviewOpen<cr>`                      | `diffview.nvim` |  |
| `<leader>cD` | n | Toggle difftastic diff view                                                      | `toggle Difft diff`                      | `difft.nvim` |  |
| `<leader>cf` | n,v | Format file or range                                                             | `conform.format`                         | `conform.nvim` |  |
| `<leader>cl` | n | Trigger linting                                                                  | `lint.try_lint`                          | `nvim-lint` |  |
| `<leader>co` | n | Diffview merge: choose OURS                                                      | `conflict: choose ours`                  | `diffview.nvim` | 🔸 |
| `<leader>ct` | n | Diffview merge: choose THEIRS                                                    | `conflict: choose theirs`                | `diffview.nvim` | 🔸 |
| `<leader>d` | n | Delete (yank into default register)                                              | `d`                                      | _core_ |  |
| `<leader>e` | n | Diffview: focus the file panel                                                   | `focus file panel`                       | `diffview.nvim` | 🔸 |
| `<leader>ed` | n | Oil: edit current file's directory                                               | `<cmd>edit %:p:h<CR>`                    | `oil.nvim` |  |
| `<leader>eD` | n | Oil: edit current working directory                                              | `<cmd>edit .<CR>`                        | `oil.nvim` |  |
| `<leader>f?` | n | Fuzzy find: help tags                                                            | `<cmd>Telescope help_tags<cr>`           | `telescope.nvim` |  |
| `<leader>fb` | n | Fuzzy find: buffers                                                              | `<cmd>Telescope buffers<cr>`             | `telescope.nvim` |  |
| `<leader>ff` | n | Fuzzy find: files                                                                | `<cmd>Telescope find_files<cr>`          | `telescope.nvim` |  |
| `<leader>fF` | n | Fuzzy find: hidden files                                                         | `<cmd>Telescope find_files hidden=true<c…` | `telescope.nvim` |  |
| `<leader>fg` | n | Fuzzy find: live grep                                                            | `<cmd>Telescope live_grep<cr>`           | `telescope.nvim` |  |
| `<leader>fh` | n | Fuzzy find: harpoon marks                                                        | `<cmd>Telescope harpoon marks<CR>`       | `telescope.nvim` |  |
| `<leader>fj` | n | Fuzzy find: jumplist entries                                                     | `<cmd>Telescope jumplist<CR>`            | `telescope.nvim` |  |
| `<leader>fk` | n | Fuzzy find: keymaps                                                              | `<cmd>Telescope keymaps<cr>`             | `telescope.nvim` |  |
| `<leader>fK` | n | Fuzzy find: keymaps by plugin                                                    | `<cmd>lua require('keymap_registry').pic…` | `telescope.nvim` |  |
| `<leader>fr` | n | Fuzzy find: recent files                                                         | `<cmd>Telescope oldfiles<cr>`            | `telescope.nvim` |  |
| `<leader>ft` | n | Fuzzy find: TODO comments                                                        | `<cmd>TodoTelescope<CR>`                 | `telescope.nvim` |  |
| `<leader>gd` | n | Gitsigns: diff this                                                              | `<cmd>Gitsigns diffthis<cr>`             | `gitsigns.nvim` |  |
| `<leader>gg` | n | Open Neogit                                                                      | `<cmd>Neogit<CR>`                        | `neogit` |  |
| `<leader>gp` | n | Gitsigns: preview hunk                                                           | `<cmd>Gitsigns preview_hunk<cr>`         | `gitsigns.nvim` |  |
| `<leader>gs` | n | Gitsigns: stage hunk                                                             | `<cmd>Gitsigns stage_hunk<cr>`           | `gitsigns.nvim` |  |
| `<leader>gu` | n | Gitsigns: undo stage hunk                                                        | `<cmd>Gitsigns undo_stage_hunk<cr>`      | `gitsigns.nvim` |  |
| `<leader>ha` | n | Harpoon: add current file                                                        | `harpoon.mark.add_file`                  | `harpoon` |  |
| `<leader>hh` | n | Harpoon: toggle quick menu                                                       | `harpoon.ui.toggle_quick_menu`           | `harpoon` |  |
| `<leader>L` | n | Open Lazy plugin manager                                                         | `<cmd>Lazy<CR>`                          | _core_ |  |
| `<leader>la` | n | LSP: code action (Lspsaga)                                                       | `:Lspsaga code_action<CR>`               | `lspsaga.nvim` |  |
| `<leader>lc` | n | LSP: run CodeLens action                                                         | `vim.lsp.codelens.run`                   | `nvim-lspconfig` |  |
| `<leader>ld` | n → hydra(diagnostics) | Enter the red hydra "diagnostics"                                                | `enter hydra`                            | `hydra.nvim` |  |
| `<leader>lo` | n | Trouble: location list                                                           | `<cmd>Trouble loclist toggle<cr>`        | `trouble.nvim` |  |
| `<leader>lq` | n | Trouble: quickfix list                                                           | `<cmd>Trouble qflist toggle<cr>`         | `trouble.nvim` |  |
| `<leader>lr` | n | LSP: rename symbol                                                               | `vim.lsp.buf.rename`                     | `nvim-lspconfig` |  |
| `<leader>ls` | n | Trouble: document symbols                                                        | `<cmd>Trouble symbols toggle focus=false…` | `trouble.nvim` |  |
| `<leader>lSl` | n | Trouble: LSP definitions/references                                              | `<cmd>Trouble lsp toggle focus=false win…` | `trouble.nvim` |  |
| `<leader>lSr` | n | LSP: restart                                                                     | `<cmd>lsp restart<CR>`                   | `nvim-lspconfig` |  |
| `<leader>p` | n | Paste from system clipboard                                                      | `"+p`                                    | _core_ |  |
| `<leader>p` | v | Paste over selection without yanking                                             | `"_dP`                                   | _core_ |  |
| `<leader>se` | n | Equalize split sizes                                                             | `<C-w>=`                                 | _core_ |  |
| `<leader>sh` | n | Split window horizontally                                                        | `<cmd>split<CR>`                         | _core_ |  |
| `<leader>sm` | n | Toggle split maximize                                                            | `<cmd>MaximizerToggle<CR>`               | `vim-maximizer` |  |
| `<leader>sq` | n | Close current split                                                              | `<cmd>close<CR>`                         | _core_ |  |
| `<leader>sv` | n | Split window vertically                                                          | `<cmd>vsplit<CR>`                        | _core_ |  |
| `<leader>tf` | n | Open current file in new tab                                                     | `<cmd>tabnew %<CR>`                      | _core_ |  |
| `<leader>tn` | n | Go to next tab                                                                   | `<cmd>tabn<CR>`                          | _core_ |  |
| `<leader>to` | n | Open new tab                                                                     | `<cmd>tabnew<CR>`                        | _core_ |  |
| `<leader>tp` | n | Go to previous tab                                                               | `<cmd>tabp<CR>`                          | _core_ |  |
| `<leader>tq` | n | Close current tab                                                                | `<cmd>tabclose<CR>`                      | _core_ |  |
| `<leader>u` | n | Browse undo history                                                              | `<cmd>Telescope undo<cr>`                | `telescope-undo.nvim` |  |
| `<leader>y` | n | Yank to system clipboard                                                         | `"+y`                                    | _core_ |  |
| `<leader>y` | v | Yank selection to system clipboard                                               | `"+y`                                    | _core_ |  |
| `<M-CR>` | n | Copilot: open suggestion panel                                                   | `open panel`                             | `copilot.lua` | 🔸 |
| `<M-l>` | i | Copilot: accept inline suggestion                                                | `accept suggestion`                      | `copilot.lua` | 🔸 |
| `<M-q>` | i,n | Telescope (default): send selected to quickfix                                   | `send_selected_to_qflist + open_qflist`  | `telescope.nvim` | 🔸 |
| `<M-[>` | i | Copilot: show previous suggestion                                                | `prev suggestion`                        | `copilot.lua` | 🔸 |
| `<M-]>` | i | Copilot: show next suggestion                                                    | `next suggestion`                        | `copilot.lua` | 🔸 |
| `<S-Tab>` | i | Completion: jump to previous snippet placeholder                                 | `prev snippet placeholder`               | `blink.cmp` | 🔸 |
| `<S-Tab>` | n | Diffview: open diff for previous file                                            | `previous file diff`                     | `diffview.nvim` | 🔸 |
| `<Tab>` | i | Completion: jump to next snippet placeholder                                     | `next snippet placeholder`               | `blink.cmp` | 🔸 |
| `<Tab>` | i,n | Telescope (default): toggle multi-selection                                      | `toggle_selection + move worse`          | `telescope.nvim` | 🔸 |
| `<Tab>` | n | Diffview: open diff for next file                                                | `next file diff`                         | `diffview.nvim` | 🔸 |
| `<Up>` | i | Completion: select previous item                                                 | `select previous`                        | `blink.cmp` | 🔸 |
| `<Up>` | i | Telescope (default): previous result                                             | `move_selection_previous`                | `telescope.nvim` | 🔸 |
| `=` | n,x | Auto-indent {motion}/selection                                                   | `(operator)`                             | _core_ | 🔹 |
| `=+` | hydra(treewalker) | Previous assignment (outer)                                                      | `goto_previous_start @assignment.outer`  | `hydra.nvim` |  |
| `==` | hydra(treewalker) | Next assignment (outer)                                                          | `goto_next_start @assignment.outer`      | `hydra.nvim` |  |
| `==` | n | Auto-indent current line                                                         | `(operator)`                             | _core_ | 🔹 |
| `==` | x,o | Textobject: assignment (outer)                                                   | `@assignment.outer`                      | `nvim-treesitter` |  |
| `=l` | hydra(treewalker) | Next assignment (lhs)                                                            | `goto_next_start @assignment.lhs`        | `hydra.nvim` |  |
| `=L` | hydra(treewalker) | Previous assignment (lhs)                                                        | `goto_previous_start @assignment.lhs`    | `hydra.nvim` |  |
| `=l` | x,o | Textobject: assignment left-hand side                                            | `@assignment.lhs`                        | `nvim-treesitter` |  |
| `=r` | hydra(treewalker) | Next assignment (rhs)                                                            | `goto_next_start @assignment.rhs`        | `hydra.nvim` |  |
| `=R` | hydra(treewalker) | Previous assignment (rhs)                                                        | `goto_previous_start @assignment.rhs`    | `hydra.nvim` |  |
| `=r` | x,o | Textobject: assignment right-hand side                                           | `@assignment.rhs`                        | `nvim-treesitter` |  |
| `>` | n | Indent line right                                                                | `>>`                                     | _core_ |  |
| `>` | v | Indent right, keep selection                                                     | `>gv`                                    | _core_ |  |
| `?` | n | CodeCompanion chat: show keymap help                                             | `chat: options/help`                     | `codecompanion.nvim` | 🔸 |
| `?` | n | Telescope (default): show mappings help                                          | `which_key`                              | `telescope.nvim` | 🔸 |
| `?` | n | Trouble window: show help                                                        | `help`                                   | `trouble.nvim` | 🔸 |
| `?` | n,x,o | Search backward                                                                  | `(search)`                               | _core_ | 🔹 |
| `@@` | n | Repeat last played macro                                                         | `(macro)`                                | _core_ | 🔹 |
| `@{reg}` | n | Play back macro from register                                                    | `(macro)`                                | _core_ | 🔹 |
| `a` | hydra(treewalker) | Next parameter (outer)                                                           | `goto_next_start @parameter.outer`       | `hydra.nvim` |  |
| `A` | hydra(treewalker) | Previous parameter (outer)                                                       | `goto_previous_start @parameter.outer`   | `hydra.nvim` |  |
| `a` | n | Insert after cursor                                                              | `(edit)`                                 | _core_ | 🔹 |
| `A` | n | Insert at end of line                                                            | `(edit)`                                 | _core_ | 🔹 |
| `A` | x | Append at end of block (blockwise)                                               | `(edit)`                                 | _core_ | 🔹 |
| `aa` | x,o | Textobject: parameter (outer)                                                    | `@parameter.outer`                       | `nvim-treesitter` |  |
| `ab` | x,o | Textobject: block (outer)                                                        | `@block.outer`                           | `nvim-treesitter` |  |
| `ac` | x,o | Textobject: comment (outer)                                                      | `@comment.outer`                         | `nvim-treesitter` |  |
| `af` | x,o | Textobject: call (outer)                                                         | `@call.outer`                            | `nvim-treesitter` |  |
| `ai` | x,o | Textobject: conditional (outer)                                                  | `@conditional.outer`                     | `nvim-treesitter` |  |
| `al` | x,o | Textobject: loop (outer)                                                         | `@loop.outer`                            | `nvim-treesitter` |  |
| `am` | x,o | Textobject: function (outer)                                                     | `@function.outer`                        | `nvim-treesitter` |  |
| `an` | x,o | Textobject: number (inner)                                                       | `@number.inner`                          | `nvim-treesitter` |  |
| `ar` | x,o | Textobject: return (outer)                                                       | `@return.outer`                          | `nvim-treesitter` |  |
| `at` | x,o | Textobject: class (outer)                                                        | `@class.outer`                           | `nvim-treesitter` |  |
| `a{id}` | x,o | mini.ai: select 'around' textobject {id}                                         | `select around textobject`               | `mini.ai` | 🔸 |
| `b` | hydra(diagnostics) | Toggle scope (buffer/project)                                                    | `toggle scope buffer/project`            | `hydra.nvim` |  |
| `b` | hydra(treewalker) | Next block (outer)                                                               | `goto_next_start @block.outer`           | `hydra.nvim` |  |
| `B` | hydra(treewalker) | Previous block (outer)                                                           | `goto_previous_start @block.outer`       | `hydra.nvim` |  |
| `b` | n,x,o | Back to start of word                                                            | `(motion)`                               | _core_ | 🔹 |
| `B` | n,x,o | Back to start of WORD                                                            | `(motion)`                               | _core_ | 🔹 |
| `c` | hydra(treewalker) | Next comment (outer)                                                             | `goto_next_start @comment.outer`         | `hydra.nvim` |  |
| `C` | hydra(treewalker) | Previous comment (outer)                                                         | `goto_previous_start @comment.outer`     | `hydra.nvim` |  |
| `c` | n | Change into black-hole register                                                  | `"_c`                                    | _core_ |  |
| `C` | n | Change to end of line                                                            | `(operator)`                             | _core_ | 🔹 |
| `c` | x | Change {motion}/selection                                                        | `(operator)`                             | _core_ | 🔹 |
| `cc` | n | Change line                                                                      | `(operator)`                             | _core_ | 🔹 |
| `cS` | n | Surround: change a pair onto new lines                                           | `change surround (new lines)`            | `nvim-surround` | 🔸 |
| `cs{target}{replacement}` | n | Surround: change a surrounding pair                                              | `change surround`                        | `nvim-surround` | 🔸 |
| `d` | hydra(diagnostics) | Next diagnostic                                                                  | `goto next diagnostic`                   | `hydra.nvim` |  |
| `D` | hydra(diagnostics) | Previous diagnostic                                                              | `goto previous diagnostic`               | `hydra.nvim` |  |
| `d` | n | Delete into black-hole register                                                  | `"_d`                                    | _core_ |  |
| `D` | n | Delete to end of line                                                            | `(operator)`                             | _core_ | 🔹 |
| `d` | x | Delete {motion}/selection                                                        | `(operator)`                             | _core_ | 🔹 |
| `dd` | n | Delete line                                                                      | `(operator)`                             | _core_ | 🔹 |
| `ds{char}` | n | Surround: delete a surrounding pair                                              | `delete surround`                        | `nvim-surround` | 🔸 |
| `e` | hydra(diagnostics) | Next error                                                                       | `goto next ERROR diagnostic`             | `hydra.nvim` |  |
| `E` | hydra(diagnostics) | Previous error                                                                   | `goto previous ERROR diagnostic`         | `hydra.nvim` |  |
| `e` | n,x,o | Forward to end of word                                                           | `(motion)`                               | _core_ | 🔹 |
| `E` | n,x,o | Forward to end of WORD                                                           | `(motion)`                               | _core_ | 🔹 |
| `f` | hydra(treewalker) | Next call (outer)                                                                | `goto_next_start @call.outer`            | `hydra.nvim` |  |
| `F` | hydra(treewalker) | Previous call (outer)                                                            | `goto_previous_start @call.outer`        | `hydra.nvim` |  |
| `f` | n,x,o | Flash: enhanced f, jump to char (dot-repeat)                                     | `enhanced f (flash char)`                | `flash.nvim` | 🔸 |
| `F` | n,x,o | Flash: enhanced F, backward jump to char                                         | `enhanced F (flash char back)`           | `flash.nvim` | 🔸 |
| `f{char}` | n,x,o | To next occurrence of {char}                                                     | `(motion)`                               | _core_ | 🔹 |
| `F{char}` | n,x,o | To previous occurrence of {char}                                                 | `(motion)`                               | _core_ | 🔹 |
| `G` | n,x,o | To last line (or line [count])                                                   | `(motion)`                               | _core_ | 🔹 |
| `g#` | n,x,o | Search backward for partial word under cursor                                    | `(search)`                               | _core_ | 🔹 |
| `g*` | n,x,o | Search forward for partial word under cursor                                     | `(search)`                               | _core_ | 🔹 |
| `g,` | n | Go to newer position in change list                                              | `(jump)`                                 | _core_ | 🔹 |
| `g.` | n | Oil: toggle hidden files                                                         | `actions.toggle_hidden`                  | `oil.nvim` |  |
| `g.` | n | Oil (default): toggle hidden files                                               | `actions.toggle_hidden`                  | `oil.nvim` | 🔸 |
| `g;` | n | Go to older position in change list                                              | `(jump)`                                 | _core_ | 🔹 |
| `g=` | n | mini.operators: evaluate text and replace with result                            | `evaluate (motion)`                      | `mini.operators` | 🔸 |
| `g=` | x | mini.operators: evaluate selection                                               | `evaluate (selection)`                   | `mini.operators` | 🔸 |
| `g==` | n | mini.operators: evaluate current line                                            | `evaluate (line)`                        | `mini.operators` | 🔸 |
| `g?` | n | Oil: show help                                                                   | `actions.show_help`                      | `oil.nvim` |  |
| `g?` | n | Oil (default): show help                                                         | `actions.show_help`                      | `oil.nvim` | 🔸 |
| `ga` | n | CodeCompanion chat: change adapter/model                                         | `chat: change adapter`                   | `codecompanion.nvim` | 🔸 |
| `ga` | n | Show character codes under cursor                                                | `(misc)`                                 | _core_ | 🔹 |
| `gb` | x | Comment: toggle selection (blockwise)                                            | `toggle blockwise comment (selection)`   | `Comment.nvim` | 🔸 |
| `gbc` | n | Comment: toggle current line (blockwise)                                         | `toggle blockwise comment (line)`        | `Comment.nvim` | 🔸 |
| `gb{motion}` | n | Comment: blockwise comment over a motion                                         | `toggle blockwise comment (operator)`    | `Comment.nvim` | 🔸 |
| `gc` | n | CodeCompanion chat: insert empty codeblock                                       | `chat: insert codeblock`                 | `codecompanion.nvim` | 🔸 |
| `gc` | x | Comment: toggle selection (linewise)                                             | `toggle linewise comment (selection)`    | `Comment.nvim` | 🔸 |
| `gcA` | n | Comment: append comment at end of line                                           | `comment end of line + insert`           | `Comment.nvim` | 🔸 |
| `gcc` | n | Comment: toggle current line (linewise)                                          | `toggle linewise comment (line)`         | `Comment.nvim` | 🔸 |
| `gco` | n | Comment: add comment on line below                                               | `comment line below + insert`            | `Comment.nvim` | 🔸 |
| `gcO` | n | Comment: add comment on line above                                               | `comment line above + insert`            | `Comment.nvim` | 🔸 |
| `gc{motion}` | n | Comment: linewise comment over a motion                                          | `toggle linewise comment (operator)`     | `Comment.nvim` | 🔸 |
| `gD` | n | LSP: go to declaration                                                           | `vim.lsp.buf.declaration`                | `nvim-lspconfig` |  |
| `gd` | n | LSP: definitions (Telescope)                                                     | `<cmd>Telescope lsp_definitions<CR>`     | `nvim-lspconfig` |  |
| `gd` | n | CodeCompanion chat: show debug info                                              | `chat: debug info`                       | `codecompanion.nvim` | 🔸 |
| `ge` | n,x,o | Back to end of previous word                                                     | `(motion)`                               | _core_ | 🔹 |
| `gE` | n,x,o | Back to end of previous WORD                                                     | `(motion)`                               | _core_ | 🔹 |
| `gf` | n | CodeCompanion chat: fold all codeblocks                                          | `chat: fold codeblocks`                  | `codecompanion.nvim` | 🔸 |
| `gf` | n | Diffview: open local file in a tabpage                                           | `goto_file`                              | `diffview.nvim` | 🔸 |
| `gf` | n | Go to file under cursor                                                          | `(jump)`                                 | _core_ | 🔹 |
| `gg` | n,x,o | To first line (or line [count])                                                  | `(motion)`                               | _core_ | 🔹 |
| `gh` | n | Oil: open entry in horizontal split                                              | `actions.select horizontal`              | `oil.nvim` |  |
| `gi` | n | LSP: implementations (Telescope)                                                 | `<cmd>Telescope lsp_implementations<CR>` | `nvim-lspconfig` |  |
| `gj` | n | History: go back                                                                 | `<cmd>HisTravBack<cr>`                   | `history-traverse` |  |
| `gJ` | n | Join line below without a space                                                  | `(edit)`                                 | _core_ | 🔹 |
| `gk` | n | History: go forward                                                              | `<cmd>HisTravForward<cr>`                | `history-traverse` |  |
| `gm` | n | mini.operators: duplicate text over motion                                       | `multiply (motion)`                      | `mini.operators` | 🔸 |
| `gm` | x | mini.operators: duplicate selection                                              | `multiply (selection)`                   | `mini.operators` | 🔸 |
| `gmm` | n | mini.operators: duplicate current line                                           | `multiply (line)`                        | `mini.operators` | 🔸 |
| `gp` | n | Oil: preview entry                                                               | `actions.preview`                        | `oil.nvim` |  |
| `gq` | n | Oil: close                                                                       | `actions.close`                          | `oil.nvim` |  |
| `gq` | x | Format {motion}/selection                                                        | `(operator)`                             | _core_ | 🔹 |
| `gr` | n | Oil: refresh                                                                     | `actions.refresh`                        | `oil.nvim` |  |
| `gR` | n | LSP: references (Telescope)                                                      | `<cmd>Telescope lsp_references<CR>`      | `nvim-lspconfig` |  |
| `gr` | n | mini.operators: replace text with register                                       | `replace w/ register (motion)`           | `mini.operators` | 🔸 |
| `gr` | n | Copilot panel: refresh suggestions                                               | `panel: refresh`                         | `copilot.lua` | 🔸 |
| `gr` | n | CodeCompanion chat: regenerate last response                                     | `chat: regenerate`                       | `codecompanion.nvim` | 🔸 |
| `gr` | x | mini.operators: replace selection with register                                  | `replace w/ register (selection)`        | `mini.operators` | 🔸 |
| `grr` | n | mini.operators: replace line with register                                       | `replace w/ register (line)`             | `mini.operators` | 🔸 |
| `gs` | n | Oil: change sort                                                                 | `actions.change_sort`                    | `oil.nvim` |  |
| `gs` | n | mini.operators: sort text over motion                                            | `sort (motion)`                          | `mini.operators` | 🔸 |
| `gs` | n | Oil (default): change sort order                                                 | `actions.change_sort`                    | `oil.nvim` | 🔸 |
| `gs` | n | CodeCompanion chat: toggle system prompt                                         | `chat: toggle system prompt`             | `codecompanion.nvim` | 🔸 |
| `gS` | n,x | mini.splitjoin: split if single line, join if multiline                          | `toggle split/join`                      | `mini.splitjoin` | 🔸 |
| `gS` | x | Surround: add pair around selection, on new lines                                | `surround selection (new lines)`         | `nvim-surround` | 🔸 |
| `gs` | x | mini.operators: sort selection                                                   | `sort (selection)`                       | `mini.operators` | 🔸 |
| `gss` | n | mini.operators: sort current line                                                | `sort (line)`                            | `mini.operators` | 🔸 |
| `gt` | n | Oil: open entry in new tab                                                       | `actions.select tab`                     | `oil.nvim` |  |
| `gt` | n | LSP: type definitions (Telescope)                                                | `<cmd>Telescope lsp_type_implementations…` | `nvim-lspconfig` |  |
| `gT` | n | Go to previous tab page                                                          | `(tab)`                                  | _core_ | 🔹 |
| `gu` | n,x | Lowercase {motion}/selection                                                     | `(operator)`                             | _core_ | 🔹 |
| `gU` | n,x | Uppercase {motion}/selection                                                     | `(operator)`                             | _core_ | 🔹 |
| `gv` | n | Oil: open entry in vertical split                                                | `actions.select vertical`                | `oil.nvim` |  |
| `gx` | n | Oil: open externally                                                             | `actions.open_external`                  | `oil.nvim` |  |
| `gx` | n | mini.operators: exchange region (2-step swap)                                    | `exchange (motion)`                      | `mini.operators` | 🔸 |
| `gx` | n | CodeCompanion chat: clear all messages                                           | `chat: clear`                            | `codecompanion.nvim` | 🔸 |
| `gx` | n,v | Oil (default): open with system app                                              | `actions.open_external`                  | `oil.nvim` | 🔸 |
| `gx` | x | mini.operators: exchange selection                                               | `exchange (selection)`                   | `mini.operators` | 🔸 |
| `gxx` | n | mini.operators: exchange current line                                            | `exchange (line)`                        | `mini.operators` | 🔸 |
| `gy` | n | CodeCompanion chat: yank last codeblock                                          | `chat: yank codeblock`                   | `codecompanion.nvim` | 🔸 |
| `g[` | n,x,o | mini.ai: move to left edge of nearest textobject                                 | `go to left edge of textobject`          | `mini.ai` | 🔸 |
| `g\` | n | Oil: toggle trash                                                                | `actions.toggle_trash`                   | `oil.nvim` |  |
| `g\` | n | Oil (default): toggle trash view                                                 | `actions.toggle_trash`                   | `oil.nvim` | 🔸 |
| `g]` | n,x,o | mini.ai: move to right edge of nearest textobject                                | `go to right edge of textobject`         | `mini.ai` | 🔸 |
| `g_` | n,x,o | To last non-blank character of line                                              | `(motion)`                               | _core_ | 🔹 |
| `g~` | n | Oil (default): :tcd to directory                                                 | `actions.cd scope=tab`                   | `oil.nvim` | 🔸 |
| `g~` | n,x | Toggle case of {motion}/selection                                                | `(operator)`                             | _core_ | 🔹 |
| `h` | hydra(diagnostics) | Next hint                                                                        | `goto next HINT diagnostic`              | `hydra.nvim` |  |
| `H` | hydra(diagnostics) | Previous hint                                                                    | `goto previous HINT diagnostic`          | `hydra.nvim` |  |
| `h` | hydra(treewalker) | Move left / ascend                                                               | `<cmd>Treewalker Left<cr>`               | `hydra.nvim` |  |
| `h` | n | Origami: fold when at/before first non-blank, else h                             | `fold or normal h`                       | `nvim-origami` | 🔸 |
| `h` | n,x,o | Left one character                                                               | `(motion)`                               | _core_ | 🔹 |
| `H` | n,x,o | To top of window                                                                 | `(motion)`                               | _core_ | 🔹 |
| `i` | hydra(diagnostics) | Next info                                                                        | `goto next INFO diagnostic`              | `hydra.nvim` |  |
| `I` | hydra(diagnostics) | Previous info                                                                    | `goto previous INFO diagnostic`          | `hydra.nvim` |  |
| `i` | hydra(treewalker) | Next conditional (outer)                                                         | `goto_next_start @conditional.outer`     | `hydra.nvim` |  |
| `I` | hydra(treewalker) | Previous conditional (outer)                                                     | `goto_previous_start @conditional.outer` | `hydra.nvim` |  |
| `i` | n | Insert before cursor                                                             | `(edit)`                                 | _core_ | 🔹 |
| `I` | n | Insert at first non-blank                                                        | `(edit)`                                 | _core_ | 🔹 |
| `I` | x | Insert at start of block (blockwise)                                             | `(edit)`                                 | _core_ | 🔹 |
| `ia` | x,o | Textobject: parameter (inner)                                                    | `@parameter.inner`                       | `nvim-treesitter` |  |
| `ib` | x,o | Textobject: block (inner)                                                        | `@block.inner`                           | `nvim-treesitter` |  |
| `ic` | x,o | Textobject: comment (outer)                                                      | `@comment.outer`                         | `nvim-treesitter` |  |
| `if` | x,o | Textobject: call (inner)                                                         | `@call.inner`                            | `nvim-treesitter` |  |
| `ii` | x,o | Textobject: conditional (inner)                                                  | `@conditional.inner`                     | `nvim-treesitter` |  |
| `il` | x,o | Textobject: loop (inner)                                                         | `@loop.inner`                            | `nvim-treesitter` |  |
| `im` | x,o | Textobject: function (inner)                                                     | `@function.inner`                        | `nvim-treesitter` |  |
| `in` | x,o | Textobject: number (inner)                                                       | `@number.inner`                          | `nvim-treesitter` |  |
| `ir` | x,o | Textobject: return (inner)                                                       | `@return.inner`                          | `nvim-treesitter` |  |
| `it` | x,o | Textobject: class (inner)                                                        | `@class.inner`                           | `nvim-treesitter` |  |
| `i{id}` | x,o | mini.ai: select 'inside' textobject {id}                                         | `select inside textobject`               | `mini.ai` | 🔸 |
| `j` | hydra(treewalker) | Move down a sibling node                                                         | `<cmd>Treewalker Down<cr>`               | `hydra.nvim` |  |
| `J` | n | Join line below with a space                                                     | `(edit)`                                 | _core_ | 🔹 |
| `j` | n,x,o | Down one line                                                                    | `(motion)`                               | _core_ | 🔹 |
| `J` | x | Move selected block down                                                         | `:move '>+1<CR>gv=gv`                    | _core_ |  |
| `k` | hydra(treewalker) | Move up a sibling node                                                           | `<cmd>Treewalker Up<cr>`                 | `hydra.nvim` |  |
| `K` | n | LSP: hover documentation                                                         | `vim.lsp.buf.hover`                      | `nvim-lspconfig` |  |
| `k` | n,x,o | Up one line                                                                      | `(motion)`                               | _core_ | 🔹 |
| `K` | x | Move selected block up                                                           | `:move '<-2<CR>gv=gv`                    | _core_ |  |
| `l` | hydra(treewalker) | Move right / descend                                                             | `<cmd>Treewalker Right<cr>`              | `hydra.nvim` |  |
| `l` | n | Origami: unfold folded line, else l                                              | `unfold or normal l`                     | `nvim-origami` | 🔸 |
| `l` | n,x,o | Right one character                                                              | `(motion)`                               | _core_ | 🔹 |
| `L` | n,x,o | To bottom of window                                                              | `(motion)`                               | _core_ | 🔹 |
| `m` | hydra(treewalker) | Next function (outer)                                                            | `goto_next_start @function.outer`        | `hydra.nvim` |  |
| `M` | hydra(treewalker) | Previous function (outer)                                                        | `goto_previous_start @function.outer`    | `hydra.nvim` |  |
| `M` | n,x,o | To middle of window                                                              | `(motion)`                               | _core_ | 🔹 |
| `m{a-zA-Z}` | n | Set mark at cursor                                                               | `(mark)`                                 | _core_ | 🔹 |
| `n` | hydra(treewalker) | Next number (inner)                                                              | `goto_next_start @number.inner`          | `hydra.nvim` |  |
| `N` | hydra(treewalker) | Previous number (inner)                                                          | `goto_previous_start @number.inner`      | `hydra.nvim` |  |
| `n` | n,x,o | Repeat last search                                                               | `(search)`                               | _core_ | 🔹 |
| `N` | n,x,o | Repeat last search, opposite direction                                           | `(search)`                               | _core_ | 🔹 |
| `o` | hydra(treewalker) | Next conditional (inner)                                                         | `goto_next_start @conditional.inner`     | `hydra.nvim` |  |
| `O` | hydra(treewalker) | Previous conditional (inner)                                                     | `goto_previous_start @conditional.inner` | `hydra.nvim` |  |
| `o` | n | Trouble window: jump to item and close                                           | `jump + close`                           | `trouble.nvim` | 🔸 |
| `o` | n | Open new line below and insert                                                   | `(edit)`                                 | _core_ | 🔹 |
| `O` | n | Open new line above and insert                                                   | `(edit)`                                 | _core_ | 🔹 |
| `o` | x | Move to other end of selection                                                   | `(visual)`                               | _core_ | 🔹 |
| `O` | x | Move to other corner (blockwise)                                                 | `(visual)`                               | _core_ | 🔹 |
| `p` | hydra(treewalker) | Next parameter (inner)                                                           | `goto_next_start @parameter.inner`       | `hydra.nvim` |  |
| `P` | hydra(treewalker) | Previous parameter (inner)                                                       | `goto_previous_start @parameter.inner`   | `hydra.nvim` |  |
| `p` | n | Trouble window: preview item                                                     | `preview`                                | `trouble.nvim` | 🔸 |
| `P` | n | Trouble window: toggle auto preview                                              | `toggle preview`                         | `trouble.nvim` | 🔸 |
| `p` | n | Paste after cursor                                                               | `(edit)`                                 | _core_ | 🔹 |
| `P` | n | Paste before cursor                                                              | `(edit)`                                 | _core_ | 🔹 |
| `q` | hydra(diagnostics) | Leave the hydra                                                                  | `exit hydra`                             | `hydra.nvim` |  |
| `Q` | n | Disable Ex mode                                                                  | `<nop>`                                  | _core_ |  |
| `q` | n | CodeCompanion chat: stop current request                                         | `chat: stop request`                     | `codecompanion.nvim` | 🔸 |
| `q` | n | Trouble window: close                                                            | `close`                                  | `trouble.nvim` | 🔸 |
| `q{a-z}` | n | Record macro into register                                                       | `(macro)`                                | _core_ | 🔹 |
| `r` | hydra(treewalker) | Next return (outer)                                                              | `goto_next_start @return.outer`          | `hydra.nvim` |  |
| `R` | hydra(treewalker) | Previous return (outer)                                                          | `goto_previous_start @return.outer`      | `hydra.nvim` |  |
| `r` | n | Trouble window: refresh                                                          | `refresh`                                | `trouble.nvim` | 🔸 |
| `r` | n | Replace single character                                                         | `(edit)`                                 | _core_ | 🔹 |
| `R` | n | Enter Replace mode                                                               | `(edit)`                                 | _core_ | 🔹 |
| `r` | o | Remote flash (operator pending)                                                  | `require('flash').remote()`              | `flash.nvim` |  |
| `R` | o,x | Treesitter search                                                                | `require('flash').treesitter_search()`   | `flash.nvim` |  |
| `S` | n → hydra(treewalker) | Enter the pink hydra "treewalker" (also unbinds the default S)                   | `enter hydra`                            | `hydra.nvim` |  |
| `s` | n | Flash jump                                                                       | `require('flash').jump()`                | `flash.nvim` |  |
| `S` | n | Diffview file panel: stage all entries                                           | `stage all (file panel)`                 | `diffview.nvim` | 🔸 |
| `S` | x | Surround: add pair around visual selection                                       | `surround selection`                     | `nvim-surround` | 🔸 |
| `t` | hydra(treewalker) | Next class (outer)                                                               | `goto_next_start @class.outer`           | `hydra.nvim` |  |
| `T` | hydra(treewalker) | Previous class (outer)                                                           | `goto_previous_start @class.outer`       | `hydra.nvim` |  |
| `t` | n,x,o | Flash: enhanced t, jump till char                                                | `enhanced t (flash till)`                | `flash.nvim` | 🔸 |
| `T` | n,x,o | Flash: enhanced T, backward jump till char                                       | `enhanced T (flash till back)`           | `flash.nvim` | 🔸 |
| `tc` | hydra(diagnostics) | Toggle CodeLenses                                                                | `toggle codelens_enabled`                | `hydra.nvim` |  |
| `ti` | hydra(diagnostics) | Toggle inlay hints                                                               | `toggle inlay hints`                     | `hydra.nvim` |  |
| `tv` | hydra(diagnostics) | Toggle virtual_lines                                                             | `toggle diagnostic virtual_lines`        | `hydra.nvim` |  |
| `t{char}` | n,x,o | Till before next {char}                                                          | `(motion)`                               | _core_ | 🔹 |
| `T{char}` | n,x,o | Till after previous {char}                                                       | `(motion)`                               | _core_ | 🔹 |
| `U` | n | Diffview file panel: unstage all entries                                         | `unstage all (file panel)`               | `diffview.nvim` | 🔸 |
| `u` | n | Undo                                                                             | `(edit)`                                 | _core_ | 🔹 |
| `u` | x | Lowercase selection                                                              | `(edit)`                                 | _core_ | 🔹 |
| `U` | x | Uppercase selection                                                              | `(edit)`                                 | _core_ | 🔹 |
| `v` | hydra(treewalker) | Next block (outer)                                                               | `goto_next_start @block.outer`           | `hydra.nvim` |  |
| `V` | hydra(treewalker) | Previous block (inner)                                                           | `goto_previous_start @block.inner`       | `hydra.nvim` |  |
| `v` | n | Start charwise Visual mode                                                       | `(visual)`                               | _core_ | 🔹 |
| `V` | n | Start linewise Visual mode                                                       | `(visual)`                               | _core_ | 🔹 |
| `w` | hydra(diagnostics) | Next warning                                                                     | `goto next WARN diagnostic`              | `hydra.nvim` |  |
| `W` | hydra(diagnostics) | Previous warning                                                                 | `goto previous WARN diagnostic`          | `hydra.nvim` |  |
| `w` | hydra(treewalker) | Next loop (outer)                                                                | `goto_next_start @loop.outer`            | `hydra.nvim` |  |
| `W` | hydra(treewalker) | Previous loop (outer)                                                            | `goto_previous_start @loop.outer`        | `hydra.nvim` |  |
| `w` | n,x,o | Forward to start of next word                                                    | `(motion)`                               | _core_ | 🔹 |
| `W` | n,x,o | Forward to start of next WORD                                                    | `(motion)`                               | _core_ | 🔹 |
| `x` | hydra(diagnostics) | Trouble diagnostics (workspace)                                                  | `<cmd>Trouble diagnostics toggle<cr>`    | `hydra.nvim` |  |
| `X` | hydra(diagnostics) | Trouble diagnostics (buffer)                                                     | `<cmd>Trouble diagnostics toggle filter.…` | `hydra.nvim` |  |
| `x` | n | Delete char without yanking                                                      | `"_x`                                    | _core_ |  |
| `X` | n | Diffview file panel: revert file to left state                                   | `restore entry (file panel)`             | `diffview.nvim` | 🔸 |
| `X` | n | Delete character before cursor                                                   | `(edit)`                                 | _core_ | 🔹 |
| `Y` | n | Yank line (like yy)                                                              | `(operator)`                             | _core_ | 🔹 |
| `y` | n,x | Yank {motion}/selection                                                          | `(operator)`                             | _core_ | 🔹 |
| `yS` | n | Surround: add pair around motion, on new lines                                   | `add surround around motion (new lines)` | `nvim-surround` | 🔸 |
| `yss` | n | Surround: add pair around current line                                           | `add surround around line`               | `nvim-surround` | 🔸 |
| `ySS` | n | Surround: add pair around line, on new lines                                     | `add surround around line (new lines)`   | `nvim-surround` | 🔸 |
| `ys{motion}{char}` | n | Surround: add pair around a motion                                               | `add surround around motion`             | `nvim-surround` | 🔸 |
| `yy` | n | Yank line                                                                        | `(operator)`                             | _core_ | 🔹 |
| `za` | n | Toggle fold under cursor                                                         | `(fold)`                                 | _core_ | 🔹 |
| `zb` | n | Scroll current line to bottom                                                    | `(scroll)`                               | _core_ | 🔹 |
| `zc` | n | Close fold under cursor                                                          | `(fold)`                                 | _core_ | 🔹 |
| `zd` | n | Delete fold under cursor                                                         | `(fold)`                                 | _core_ | 🔹 |
| `zf` | n,x | Create fold over {motion}/selection                                              | `(operator)`                             | _core_ | 🔹 |
| `zj` | n | Move to start of next fold                                                       | `(motion)`                               | _core_ | 🔹 |
| `zk` | n | Move to end of previous fold                                                     | `(motion)`                               | _core_ | 🔹 |
| `zM` | n | Close all folds                                                                  | `(fold)`                                 | _core_ | 🔹 |
| `zo` | n | Open fold under cursor                                                           | `(fold)`                                 | _core_ | 🔹 |
| `ZQ` | n | Quit without writing                                                             | `(misc)`                                 | _core_ | 🔹 |
| `zR` | n | Open all folds                                                                   | `(fold)`                                 | _core_ | 🔹 |
| `zt` | n | Scroll current line to top                                                       | `(scroll)`                               | _core_ | 🔹 |
| `zz` | n | Center current line in window                                                    | `(scroll)`                               | _core_ | 🔹 |
| `ZZ` | n | Write file and quit                                                              | `(misc)`                                 | _core_ | 🔹 |
| `[x` | n | Diffview merge: jump to previous conflict                                        | `previous conflict`                      | `diffview.nvim` | 🔸 |
| `[[` | n | Copilot panel: jump to previous suggestion                                       | `panel: prev suggestion`                 | `copilot.lua` | 🔸 |
| `[[` | n | CodeCompanion chat: jump to previous message header                              | `chat: previous header`                  | `codecompanion.nvim` | 🔸 |
| `[[` | n,x,o | Backward to section/'{' in column 1                                              | `(motion)`                               | _core_ | 🔹 |
| `]x` | n | Diffview merge: jump to next conflict                                            | `next conflict`                          | `diffview.nvim` | 🔸 |
| `]]` | n | Copilot panel: jump to next suggestion                                           | `panel: next suggestion`                 | `copilot.lua` | 🔸 |
| `]]` | n | CodeCompanion chat: jump to next message header                                  | `chat: next header`                      | `codecompanion.nvim` | 🔸 |
| `]]` | n,x,o | Forward to section/'{' in column 1                                               | `(motion)`                               | _core_ | 🔹 |
| `^` | n | Origami: fold recursively when before first non-blank, else ^                    | `fold recursively or normal ^`           | `nvim-origami` | 🔸 |
| `^` | n,x,o | To first non-blank character of line                                             | `(motion)`                               | _core_ | 🔹 |
| `_` | n | Oil: open current working directory                                              | `actions.open_cwd`                       | `oil.nvim` |  |
| `_` | n | Oil (default): open current working directory                                    | `actions.open_cwd`                       | `oil.nvim` | 🔸 |
| `'` | n | Oil: :cd to directory                                                            | `actions.cd`                             | `oil.nvim` |  |
| `'` | n | Oil (default): :cd to directory                                                  | `actions.cd`                             | `oil.nvim` | 🔸 |
| `{` | hydra(diagnostics) | First diagnostic                                                                 | `goto first diagnostic`                  | `hydra.nvim` |  |
| `{` | n | CodeCompanion chat: open previous chat                                           | `chat: previous chat`                    | `codecompanion.nvim` | 🔸 |
| `{` | n | Trouble window: previous item                                                    | `previous item`                          | `trouble.nvim` | 🔸 |
| `{` | n,x,o | Backward one paragraph                                                           | `(motion)`                               | _core_ | 🔹 |
| `\|` | n,x,o | To column [count]                                                                | `(motion)`                               | _core_ | 🔹 |
| `}` | hydra(diagnostics) | Last diagnostic                                                                  | `goto last diagnostic`                   | `hydra.nvim` |  |
| `}` | n | CodeCompanion chat: open next chat                                               | `chat: next chat`                        | `codecompanion.nvim` | 🔸 |
| `}` | n | Trouble window: next item                                                        | `next item`                              | `trouble.nvim` | 🔸 |
| `}` | n,x,o | Forward one paragraph                                                            | `(motion)`                               | _core_ | 🔹 |
| `~` | n | Oil: :tcd to directory                                                           | `actions.cd scope=tab`                   | `oil.nvim` |  |

