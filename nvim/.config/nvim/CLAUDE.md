# CLAUDE.md

Instructions for coding agents that change this Neovim configuration.
This directory is a GNU stow package. Its files appear at `~/.config/nvim`.

## Plugin pins

lazy.nvim loads all plugins. Each plugin has one spec file in `lua/plugins/`.
Two shared libraries have their specs in `lua/plugins.lua`. The file
`lazy-lock.json` records the installed commit of each plugin.

Each spec must have `commit = "<full 40-character SHA>"`. Each entry in a
`dependencies` list must also have a `commit` unless it is a plugin with its own \*.lua file. An unpinned plugin fetches the
upstream HEAD at the next sync. A compromised upstream then runs in the editor
with no review. The pin prevents this supply-chain risk.

Write the full SHA. A short SHA can match more than one object. In this
repository a short SHA once named an annotated tag object, not the commit.
Old specs with short SHAs stay unchanged until you update that plugin.

Don't use tags, since they are redundant to the commit SHA.
Any plugin configs that have both `commit` and `tag`
should have their `tag` removed (same goes for `version`).

## Plugin updates

Update a plugin only when the user asks for an update of that plugin in the
current session. The user request is the review gate. Do not update plugins
as a side effect of other work. If you conclude that an update is necessary ask the user for confirmation. The option `checker.enabled` in
`lua/config/lazy.lua` only shows a notification. Keep it that way.

Select the target commit with this procedure:

1. Find the newest release tag that is 14 days old or older.
2. If the plugin has no releases, find the newest commit on the tracked
   branch that is 14 days old or older.
3. Read the commits after the candidate. If a later commit corrects a defect
   in the candidate, move back to the commit before the defect. Do this check
   again for the new candidate.
4. Resolve the candidate to a full commit SHA. Run `git fetch --tags` and then
   `git rev-parse '<ref>^{commit}'` in the clone at
   `~/.local/share/nvim/lazy/<plugin>/`. The suffix `^{commit}` gives the
   commit behind an annotated tag.
5. Write `commit` in the spec. Run `:Lazy restore`.
6. Run `./verify/verify.sh --sync`. See "Verifying changes" below. Update
   one plugin at a time and verify each, so a finding names the plugin
   that caused it.
7. Commit the spec and `lazy-lock.json` together.

Why 14 days: a malicious or broken commit is usually found and reverted in
days. The delay lets upstream and other users find it first.

The update is complete when the spec `commit`, the `lazy-lock.json` commit,
and the HEAD of the installed clone are the same SHA, and `verify.sh`
passes.

Matching SHAs are not enough on their own. A major release may rename a
module this config calls by name, which no pin check catches. Upgrading
catppuccin to v2.0.0 moved
`catppuccin.groups.integrations.bufferline` to `catppuccin.special.bufferline`
and renamed the lualine theme `catppuccin` to `catppuccin-nvim`, and both
broke this config. After a major version bump, grep this directory for the
plugin's name and check every hit against the new tree.

## Verifying changes

Run `verify/verify.sh` after any change to this configuration. It checks
the config in a sandbox profile and exits non-zero on any finding.

```sh
./verify/verify.sh            # check the config as lazy-lock.json pins it
./verify/verify.sh --sync     # move clones to the specs' commits first
./verify/verify.sh --clean    # discard the sandbox and install from scratch
```

Use `--sync` to check a pin you have written into a spec but not yet
synced. The sandbox keeps its own XDG directories, so it never touches
the plugins or state of the profile you use. Its config directory is a
symlink to this one, so an edit here takes effect on the next run with no
copy step. Plugin clones persist between runs under
`$XDG_CACHE_HOME/nvim-config-verify`; the first run installs them and
takes a few minutes, later runs take about a minute.

Do not check a config change by starting Neovim and watching it. Three
failures pass that way, and each one has already shipped a broken config
here:

1. lazy.nvim catches an error thrown by a plugin's `config` and reports it
   through `vim.notify`. A `pcall` around `lazy.load()` returns success.
   `check.lua` intercepts `vim.notify` instead and treats any ERROR or
   WARN as a finding.
2. A lazy-loaded plugin never runs its `config` until its trigger fires,
   so opening one file exercises almost nothing. `check.lua` forces every
   plugin through `lazy.load()`, then opens both a Lua file and a Rust
   file, because a Lua-only check misses everything behind `BufReadPre`
   for other filetypes.
3. A plugin may defer its complaint. lualine waits two seconds after
   `VimEnter` before warning that its theme was not found. `check.lua`
   waits that out before it summarizes.

`verify/fixture/` is a real crate, committed so that no one has to build
one, and so rust-analyzer has a `Cargo.toml` to attach to.
`verify/fixture-cs/` is the same idea for C#: a real project, so roslyn has
a `.csproj` to attach to. `check.lua` requires rust-analyzer and roslyn to
attach only when they are on `PATH`. The Lua probes expect no client,
because the servers come from mason and the sandbox does not install them.

`verify.sh` restores `lazy-lock.json` after every run and says so when it
had to. The sandbox bootstraps its own lazy.nvim and resolves branch
names itself, so a run that wrote the lockfile would change pins that no
one reviewed. Update the lockfile only through the procedure above, in
the profile you use.

When you change `check.lua`, prove the new check fails. Break the thing
it looks for, run `verify.sh`, confirm it reports the finding, then put
the config back. A check that has never failed is not known to work: the
first `lualine` check written here passed against a config whose theme
was already broken.

## Keybindings

`keybindings.yaml` is the inventory of all keybindings. `keybindings.md` is
a reference that a script generates from the inventory. Do not edit
`keybindings.md`. The next generation removes a manual edit.

When you add, change or remove a keybinding in a Lua file, do this:

1. Make the same change to the matching entry in `keybindings.yaml`.
2. Regenerate the reference from this directory:
   ```sh
   dotnet run keybindings-to-md.cs
   ```
   The script reads `keybindings.yaml` and writes `keybindings.md`. It has
   no `--help`. Its options are `-w N` (description width) and `-a N`
   (action width).
3. Commit the Lua file, the inventory and the reference together.

The header comment of `keybindings.yaml` (lines 1 to 35) gives the entry
rules. Two rules are easy to get wrong:

- Each entry is one binding. Do not put a forward and a backward key in one
  entry.
- A hydra head is a bare key with the mode `hydra(<name>)`. The body key is
  a separate entry with a `hydra` field.

## Inventory queries

The inventory has 759 lines and the reference has 2318 lines. Query them.
Do not read them fully. Both options below return only the matching entries.

### Option A: find-keybind.sh

`find-keybind.sh` searches the inventory by key, mode, type, plugin, group
or file. Run `./find-keybind.sh --help` for the options. Do not read the
script. The output is a JSON array. Exit code 1 means no match.

```sh
./find-keybind.sh '<C-S>'                        # one key, all modes
./find-keybind.sh -p flash.nvim                  # all bindings of one plugin
./find-keybind.sh -c i -m 'hydra(diagnostics)'   # one hydra head
```

### Option B: yq with jq filters

The installed `yq` is the Python wrapper around `jq`. It accepts jq filters
and writes JSON. Schema of `keybindings.yaml`:

```
meta:              { leader, localleader, config_root }
keybindings:       [entry]  # source "explicit": set in this config; file != ""
default_bindings:  [entry]  # source "default":  plugin defaults; file == ""
builtin_bindings:  [entry]  # source "builtin":  Neovim core; file == "" and plugin == ""

entry:
  key:          string     # the keys you press, e.g. "<leader>ld"
  mode:         [string]   # n i c v x o t, or "hydra(<name>)" for a hydra head
  action:       string     # right-hand side, or a short verb phrase
  description:  string
  file:         string     # path relative to this directory; "" when not set here
  plugin:       string     # "" for core config and Neovim built-ins
  group:        string     # logical group, e.g. "Editing", "Git" (34 values)
  source:       "explicit" | "default" | "builtin"
  hydra:        { name: string, color: "red" | "pink" }  # only on a hydra body entry
```

Example filters:

```sh
# one key in the explicit list
yq -c '.keybindings[] | select(.key == "<leader>ld")' keybindings.yaml
# all bindings of one plugin, from all three lists
yq -c '[.keybindings[], .default_bindings[], .builtin_bindings[]][] | select(.plugin == "flash.nvim")' keybindings.yaml
# all heads of one hydra
yq -c '.keybindings[] | select(.mode | index("hydra(diagnostics)"))' keybindings.yaml
# all group names
yq -r '[.keybindings[], .default_bindings[], .builtin_bindings[]] | map(.group) | unique[]' keybindings.yaml
# key and description of all bindings set in plugin specs
yq -c '.keybindings[] | select(.file | startswith("lua/plugins/")) | {key, description}' keybindings.yaml
```

## Directory map

Tags: `entry` `options` `keymaps` `plugin-spec` `generated` `inventory`
`script` `lockfile` `hydra` `ui`.

| Path                               | Description                                                                                       | Tags           |
| ---------------------------------- | ------------------------------------------------------------------------------------------------- | -------------- |
| `init.lua`                         | Entry point. Loads defaults, the keymap registry, lazy.nvim and the keymaps.                      | entry          |
| `lazy-lock.json`                   | Installed commit of each plugin. Commit it together with spec changes.                            | lockfile       |
| `keybindings.yaml`                 | The keybinding inventory. Edit this file, not the reference.                                      | inventory      |
| `keybindings.md`                   | Reference generated from the inventory. Do not edit.                                              | generated      |
| `keybindings-to-md.cs`             | .NET 10 script that generates the reference from the inventory.                                   | script         |
| `find-keybind.sh`                  | Bash and yq query tool for the inventory.                                                         | script         |
| `verify/verify.sh`                 | Sandbox check of the whole config. Run it after any change. Exits non-zero on a finding.          | script         |
| `verify/check.lua`                 | The checks `verify.sh` runs inside the sandbox profile.                                           | script         |
| `verify/fixture/`                  | Committed Rust crate the check opens, so rust-analyzer and the Rust parser get exercised.         | script         |
| `verify/fixture-cs/`               | Committed .NET project the check opens, so roslyn and the C# parser get exercised.                | script         |
| `lua/defaults.lua`                 | Core options, leader keys and the statuscolumn setup.                                             | options        |
| `lua/keymaps.lua`                  | Global keymaps that belong to no plugin.                                                          | keymaps        |
| `lua/keymap_registry.lua`          | Wraps the keymap functions before plugins load and records which file owns each map.              | keymaps        |
| `lua/diagnostice.lua`              | Diagnostic signs and config. `init.lua` does not load it. The name is a known typo.               | options        |
| `lua/statuscolumn.lua`             | Custom statuscolumn with a gradient fold column.                                                  | ui             |
| `lua/oil_status.lua`               | Modified-buffer indicator column for oil.nvim.                                                    | ui             |
| `lua/plugins.lua`                  | Specs for the two shared libraries nvim-web-devicons and plenary.nvim.                            | plugin-spec    |
| `lua/config/lazy.lua`              | lazy.nvim bootstrap and setup. Imports `lua/plugins/`.                                            | plugin-spec    |
| `lua/config/hydra-codenav.lua`     | Treesitter code-navigation hydra. Body key `S`.                                                   | hydra, keymaps |
| `lua/config/hydra-diagnostics.lua` | Diagnostics hydra. Body key `<leader>ld`.                                                         | hydra, keymaps |
| `lua/plugins/`                     | One lazy.nvim spec per plugin, 55 files. Each starts with a purpose comment and the upstream URL. | plugin-spec    |
