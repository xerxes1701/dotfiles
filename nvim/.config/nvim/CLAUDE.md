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
   Commit the spec and `lazy-lock.json` together.

Why 14 days: a malicious or broken commit is usually found and reverted in
days. The delay lets upstream and other users find it first.

The update is complete when the spec `commit`, the `lazy-lock.json` commit,
and the HEAD of the installed clone are the same SHA.

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
| `lua/plugins/`                     | One lazy.nvim spec per plugin, 54 files. Each starts with a purpose comment and the upstream URL. | plugin-spec    |
