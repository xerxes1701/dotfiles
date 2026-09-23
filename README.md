# content

contains verisioned dotfiles. files can be mirrored under ~ via `gnu stow`

# usage

each top level directory is one `gnu stow` package holding the paths it owns
relative to `~`, so `nvim/.config/nvim/init.lua` is linked as
`~/.config/nvim/init.lua`. deploy them with:

> scripts/.local/bin/stow-deploy.sh

inside a devcontainer, which replaces two of the packages with its own:

> scripts/.local/bin/stow-deploy-devcontainer.sh

and on a windows machine, from git bash, which replaces one -- see
[windows](#windows):

> scripts/.local/bin/stow-deploy-windows.sh

on a windows account that may not create symlinks, that one cannot run, and a
powershell script deploys the same set with junctions and environment variables
instead:

> scripts/.local/bin/deploy-windows-noadmin.ps1

`scripts/` is a package like the others: its executables live in `.local/bin`
and the libraries they source in `.local/lib/dotfiles`, so after the first
deploy every script here is on `PATH` under its bare name and the rest of this
file calls them that way.

all three are `stow */` with the two things that instruction gets wrong. stow
folds a package into a single symlink when its target directory does not exist
yet, so `~/.config/fish`, `~/.config/herdr` and `~/.ssh` become links into this
repository and everything those tools write there -- fisher's plug-ins, herdr's
socket, logs and session, ssh's keys and known_hosts -- lands in the working
tree; the scripts stow all three unfolded. and a container leaves `git` and
`herdr` out, in favour of the packages it replaces them with, and `ssh` out
because it mounts the host's `~/.ssh` as it is; windows leaves `herdr` out for
`.herdr-windows`.

`-n` shows what would happen and changes nothing, `--list` the packages a
script deploys, `-R` re-creates the links after a package lost a file, `-D`
removes them, `--target` deploys somewhere other than `~`, `--help` explains
the rest. each script refuses to run in another's environment. naming
packages deploys only those:

> stow-deploy.sh nvim tmux

nushell needs `nu-regen-init.nu` once per machine afterwards, see
[shells](#shells), claude code needs `claude-bootstrap.sh`, see
[claude code](#claude-code), and the pane-navigation scheme needs
`nav-setup.sh`, see [navigation](#navigation).

## restowing after a move

when a file moves between packages here, the links on a machine still point at
the old path and go dangling. `stow` recognises them as its own and repairs
them in place, so re-running the deploy script is enough. links whose source
was deleted outright are not repaired -- find those with:

> find ~ -xtype l ! -path "$HOME/dotfiles/*" -printf '%p -> %l\n' | grep dotfiles

# dependencies

## gnu stow

[gnu stow github page](https://github.com/aspiers/stow)
[gnu stow home page](https://www.gnu.org/software/stow/)

install

> sudo apt install stow

## zgen

zsh plugin manager

[zgen github page](https://github.com/tarjoilija/zgen)

install:

> git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"

## zoxide

better cd

[zoxide github page](https://github.com/ajeetdsouza/zoxide)

install

> sudo apt install zoxide

## fzf

command-line fuzzy finder
[fzf github page](https://github.com/junegunn/fzf)

### install

use latetest binary release. replace existing.

### configuration

see `.zshrc_fzf`

### dependencies

- [bat](#bat)
- [tree](#tree)

## bat

cat with syntax highlighting
[bat github page](https://github.com/sharkdp/bat)

note: on Debian/Ubuntu the binary is named `batcat`; on Arch it is `bat`.
each shell config bridges the name only when that is actually the case
(`bat` absent, `batcat` present), so the alias never shadows a working `bat`.

## tree

lists contents of directories as a tree

[tree man page page](https://manpages.ubuntu.com/manpages/focal/en/man1/tree.1.html)

install

> sudo apt install tree

## eza

`ls` alternative

[eza github page](https://github.com/eza-community/eza)

install

> sudo apt install eza

## lua + luarocks

scripting language + package manager
[lua home page](https://www.lua.org/)
[LuaRocks home page](https://luarocks.org/)

install

> sudo apt install lua luarocks

## neovim

eidtor
[neovim home page](https://neovim.io/)

install

> sudo apt install neovim

## tree-sitter-cli

dependency of nvim-treesitter (`main` branch): it builds every parser with
this CLI, version 0.26.1 or later. The Ubuntu package is 0.20.8 and too old;
without a usable CLI every parser build fails and opening a Typst file
errors in markview.nvim (2026-09-09).

install

> cargo install --locked tree-sitter-cli

## zig

programming language, C compatible, easy to install on Windows
some neovim plugins, like TreeSitter need a C compiler
[zig home page](https://ziglang.org)

install

> winget install --exact --id zig.zig

## ripgrep

regex search, faster alternative to grep
[riggrep github page](https://github.com/BurntSushi/ripgrep)

install

> sudo apt install ripgrep

## git delta

a syntax-highlighting pager for git
[git delta github page](https://github.com/dandavison/delta)

install

> sudo apt install git-delta

## fished

a fish shell plugin managet
[fisher github page](https://github.com/jorgebucaran/fisher)

install

> curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

## catppuccin fish

a fish shell color scheme
[catppuccin fish github page](https://github.com/catppuccin/fish)

install

> fisher install catppuccin/fish

no `fish_config theme save` step: `fish/.config/fish/config.fish` selects the
theme itself with `fish_config theme choose catppuccin-mocha`, so the choice
lives in this repository instead of in each machine's `fish_variables`.

the name is the file name the plugin installs. upstream renamed the themes to
lower case with a hyphen, so the `"Catppuccin Mocha"` this README used to name
now fails with `No such theme`.

## tmux

a terminal multiplexer
[tmux github page](https://github.com/tmux)

install

> sudo apt install tmux

## tmux plugin manager

plugin manager for tmux
[tpm github page](https://github.com/tmux-plugins/tpm)

install

> git clone https://github.com/tmux-plugins/tpm

## build essentials

copilers, make, etc.

install

> sudo apt install build-essentials

## entr

event notify test runner
[entr github page](https://github.com/eradman/entr)

install

> git clone https://github.com/eradman/entr
> cd entr
> ./configure
> make test
> make install

## rust

rust language compiler and tool chain
[rust home page](https://www.rust-lang.org/)

install

> curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

## yazi

commandline file manager
[yazi github homepage](https://github.com/sxyazi/yazi)

install

> cargo install --locked yazi-fm yazi-cli

## yq

lightweight YAML, JSON, XML processor
required for tmux-nerd-font-window-name plugin
[yq github page](https://github.com/mikefarah/yq)

install

> sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
> sudo chmod +x /usr/bin/yq

## ruby

scripting language, includes the `gem` package manager

install

> sudo apt install ruby

## tmuxinator

configure tmux sessions (intial windows, panes, commands)
[tmuxinator github page](https://github.com/tmuxinator/tmuxinator)

install

> gem install tmuxinator

## freerdp

rdp client, used to reach the windows machine on the lan
[freerdp github page](https://github.com/FreeRDP/FreeRDP)

install

> yay -S freerdp 1password-cli

the package installs one binary per display backend, and every name carries the
major version -- there is no plain `freerdp3`:

    xfreerdp3       x11
    wlfreerdp3      wayland
    sdl-freerdp3    sdl

the `rdp` alias in all three shells wraps the connection. the password is piped
in from 1password rather than passed as `/p:`, which would leave it in shell
history and, for as long as the session lives, in `/proc/<pid>/cmdline`:

> op read "op://<vault>/<item>/password" | xfreerdp3 /v:<host> /d:MicrosoftAccount /u:<user> /from-stdin +dynamic-resolution +clipboard /cert:ignore

nushell gets a `def` rather than an alias, because it mis-parses an alias whose
body contains a pipe. `shell-parity.sh` knows about that case.

`op` needs the desktop app's cli integration enabled (settings > developer >
integrate with 1password cli), or it cannot unlock non-interactively -- and
since its stdout is already piped into freerdp, a missed unlock prompt looks
like an rdp hang rather than an auth error.

a microsoft account signs in as the full email address under the
`MicrosoftAccount` pseudo-domain, using the account password -- not the windows
hello pin, which is device-local and cannot travel over rdp. an account set to
passwordless has no credential nla can send and must have a password restored
before it will connect at all.

## shells

fish, nushell and zsh are configured to behave the same way. each config is
split into the same labeled sections in the same order:

    env / path / tool init / aliases: listing / aliases: navigation /
    aliases: tools / aliases: system / functions / shell-specific

only the last section may differ between shells.

    fish/.config/fish/config.fish
    nushell/.config/nushell/env.nu      env + path (loaded first)
    nushell/.config/nushell/config.nu   everything else
    zsh/.zshrc

to check they have not drifted apart:

> shell-parity.sh

it asks each shell to enumerate its own aliases, functions, env vars and PATH
in a clean environment, then reports anything defined in one shell but not the
others. intentional differences are listed with a reason in
`scripts/.local/lib/dotfiles/shell-parity.allow`; it exits non-zero on
anything else.

nushell needs one extra step, because it cannot `source` a pipeline the way
`zoxide init fish | source` does. run this once per machine, and again after
upgrading zoxide or starship:

> nu-regen-init.nu

that writes starship's init into `~/.config/nushell/autoload/` (picked up
automatically) and zoxide's into `~/.config/nushell/zoxide.nu` (sourced by
name from config.nu -- zoxide's defs and PWD hook do not take effect from an
autoload dir). both are generated and machine-local, deliberately not tracked
here: the previous setup committed a `zoxide init` dump that went stale
whenever zoxide was upgraded.

# browsing

there is no linux browser on the wsl machine: `www-browser` is lynx, `open` is
a symlink to `xdg-open`, and no `x-www-browser` alternative is registered. the
only real browser is the windows one, and `/etc/wsl.conf` sets
`appendWindowsPath = false`, so it is reached only by naming `explorer.exe` in
full and translating the path first.

> browse.sh [-c] [--] [target...]
> <command> | browse.sh [-c]

aliased to `br` in all three shells. targets are files, directories or urls,
and with no target stdin is read: if every line is an existing path or a url
they are all opened, anything else is treated as content -- written to a file
under `/tmp` and opened from there. `-c` forces that reading when a list of
paths is what should be rendered instead, `--help` explains the rest. so both
halves of this work, which is the whole point:

> br lessons/01.html main.pdf
> fd -e html | fzf | br
> curl -s https://example.com | br

four measured details are why this is a script and not an alias:

    wslpath -w sb.html       -> sb.html      relative paths are not translated
                                             -- and relative is exactly what
                                             fzf prints
    wslpath -w https://x/    -> https\x\     a url has to bypass wslpath
    wslpath -w /no/such.html -> a path       existence is the script's to
                                             check, or windows opens a dialog
    explorer.exe <anything>  -> exit 1       always, even on success

piped content is typed by its first bytes, because the extension is what
decides which windows program gets the file: a pdf stays a pdf, html and svg
are passed through, everything else is wrapped in a `<pre>` page -- left as
`.txt` it would open notepad, and this command is called browse. the temporary
file is deliberately never cleaned up: the opener returns long before the
browser has read it.

outside wsl the script falls through to `xdg-open`, so the same alias works on
a linux machine. bash does not get the alias -- `~/.bashrc` is not stowed here
-- but `browse.sh` is on `PATH` there like every other script in `scripts/`.

# archives

> archive.sh -c [-f FILE]... [-d DIR]... [-o ARCHIVE] [-n] [-F] [FILE...]
> archive.sh -u [-o DIR] [-n] [-F] ARCHIVE...

one front end for tar, zip, 7z, rar and the single-file compressors. the
format comes from the file name -- of `--out` when packing, of each archive
when unpacking -- and the tool from whatever is installed, 7zz before 7z
before bsdtar and so on; a missing one is named with the package that ships
it before anything runs. `-f` takes a quoted glob, `**` included, and repeats;
`-d` packs a directory; `-n` prints the commands instead.

    archive.sh -u foo.tar.gz bar.zip -o out    both into out/
    archive.sh -c -d src -f '*.md' -o x.7z     a directory and some files
    archive.sh -c -d notes                     notes.tar.gz

every tool has its own answer to a file that is already there -- tar
overwrites, unzip asks on the terminal, and zip, 7z and rar add to an existing
archive instead of replacing it. the script gives them one: nothing existing
is touched without `-F`. a new archive is written under a scratch name and
moved into place when it is complete, so a failure or ctrl-c leaves neither
half an archive nor a damaged old one.

# navigation

nvim, tmux, herdr and zellij all have panes and all have tabs, and each of them
used to name those things with different keys. this is one scheme across all
seven combinations -- nvim alone, each multiplexer alone, and each multiplexer
with nvim inside it. nvim took precedence wherever the four disagreed.

the prefix picks the *level*, the letter picks the *action*:

    no prefix       the pane grid. nvim splits and multiplexer panes are one
                    grid, and these keys cross the boundary between them
    C-a             the multiplexer's own panes and tabs
    C-a + shift     the multiplexer's sessions, which herdr calls workspaces
    <Space>         inside nvim, the same actions one level in
    alt             herdr only: the workspace level again, off the prefix
    alt+shift       herdr only: the agent panel, which nothing else has

so `C-a v` opens a new multiplexer pane to the right and `<Space>s v` a new
nvim split to the right: same letter, and the level is whichever prefix your
left hand reached for. one prefix serves all three multiplexers because they
are alternatives here, never nested -- and `C-a` is the one nvim had already
given up (increment lives on `<Space>+`), which leaves `C-b` free for nvim's
page-up instead of being swallowed by herdr's or zellij's default prefix.
`C-a C-a` sends a literal `C-a` for the shell's beginning-of-line, in all of
them.

    action               nvim                  tmux               herdr          zellij
    -------------------  --------------------  -----------------  -------------  ----------
    focus a pane         C-h C-j C-k C-l       (the same)         (the same)     (the same)
    resize a pane        C-arrows              (the same)         (the same)     (the same)
    previous pane        C-\                   C-a \              C-a \          C-a \
    split right          <Space>sv             C-a v              C-a v          C-a v
    split below          <Space>s-             C-a -              C-a -          C-a -
    close pane           <Space>sx             C-a X              C-a X          C-a X
    zoom pane            <Space>sz             C-a z              C-a z          C-a z
    equalize panes       <Space>se             C-a e              --             --
    cycle pane           <Space>so             C-a o              C-a o          C-a o
    new tab              <Space>tc             C-a c              C-a c          C-a c
    next / prev tab      <Space>tn tp          C-a n p            C-a n p        C-a n p
    next / prev tab      <Space><Tab>/<S-Tab>  C-a <Tab>/<S-Tab>  (the same)     (the same)
    close tab            <Space>tx             C-a C-x            C-a C-x        C-a C-x
    tab 1..9             <Space>1..9           C-a 1..9           C-a 1..9       C-a 1..9
    session picker       <Space>ww             C-a w              C-a w          C-a w
    next / prev session  --                    C-a j k            C-a j k        --
    next / prev space    --                    --                 M-j / M-k      --
    next / prev agent    --                    --                 M-S-j / M-S-k  --
    new session          <Space>wN             C-a N              C-a N          --
    close session        <Space>wD             C-a D              C-a D          --
    detach               --                    C-a Q              C-a Q          C-a Q
    help                 <Space>?              C-a ?              C-a ?          C-a ?
    lock / unlock        --                    --                 --             C-z

two conventions carry the weight: the closing keys go one modifier out from
their plain letter, `X` for the inner thing and `C-x` for the outer one, so that
a slipped `C-a z` cannot close anything; and `Tab` means tab at every level.

zellij is the one that starts locked, which is its own habit and not the
scheme's: `C-z` unlocks it, `C-z` locks it again, and until it is unlocked the
prefix ladder does nothing. layer 0 is bound in locked mode as well, so the pane
grid crosses app boundaries either way -- that is the part you want before you
have decided you are doing anything. it is also modal underneath, and its own
`C-p`, `C-n`, `C-t`, `C-s` and `C-o` mode switches are left alone; only `C-h`
had to go, because that key is layer 0's in all four apps, so move mode is on
`C-a m` instead.

the rows zellij cannot fill are the session level. it can pick a session and it
can detach, and that is all: there is no action for cycling, creating, renaming
or killing a session from inside one, so `C-a j k N D W` have nothing to bind
to. `C-a e` is the other gap, in a different direction -- zellij has no equalize
action, and `e` there is herdr's `edit-scrollback` instead.

the two `M-` rows are herdr's alone. moving between workspaces is frequent
enough to want it off the prefix, so it is `alt` with the same `j` and `k`;
`C-a j` and `C-a k` still work, through `herdr-cycle-workspace.sh` -- herdr
binds one key per action, and keeping the prefix form is what keeps that rung
of the ladder the same as tmux's. the agent panel is a level nothing else has,
which is why it can afford the deepest chord.

`alt+letter` arrives as ESC plus the letter on every terminal, so it needs no
keyboard protocol and can never collapse onto the `ctrl` pane-focus keys.

`C-\` is the one key on two levels at once: inside nvim it is `<C-w>p`, and in
a bare tmux pane it is tmux's last-pane. `C-a \` is the multiplexer's own, and
it is the only form herdr can offer -- a root-level `ctrl+\` there would reach
herdr even from an nvim pane and move the wrong level's panes.

## how the pane grid crosses apps

`smart-splits.nvim` is the whole compatibility layer. it ships back-ends for
both tmux and herdr, and both of them ask the editor rather than guessing:
tmux branches on `@pane-is-vim`, a pane-local option nvim sets when it loads
and clears when it exits, and herdr runs a plugin that inspects the focused
pane's foreground process. it replaced `vim-tmux-navigator`, which only knew
tmux and decided by matching `ps` output against a regex.

one checkout serves those three. nvim pins it in
`nvim/.config/nvim/lua/plugins/smart-splits.lua` and `lazy-lock.json`,
`tmux/.config/tmux/navigation.conf` sources the tmux side straight out of
nvim's checkout instead of letting tpm clone a second copy at master HEAD, and
herdr links its plugin against the same directory. three sides of one
protocol; pinning two of them and not the third is how they would drift.

zellij is the fourth side and the only one that checkout cannot serve: there is
nothing in zellij for it to branch on, no pane-local option nvim can set on load
and clear on exit. so layer 0 there runs through `vim-zellij-navigator`, a wasm
plugin that makes the same decision from the other side -- it asks zellij which
client is focused and forwards the key when that pane is running an editor. it
is a release artifact rather than a checkout, so it is pinned by version and
checksum in `nav-setup.sh`, which is also what installs it; `config.kdl` names
it once, as a plugin alias, and the eight layer-0 binds go through that alias.
the version pinned is the one the pinned `smart-splits.nvim` documents, and not
the newest, for the same reason tmux does not clone its own copy.

that plugin needs one thing said out loud, because nothing else in this scheme
does: zellij grants a plugin its permissions at a `(y/n)` prompt, once per
machine, and the prompt is only raised when something first messages the plugin
-- so it appears on the first `C-h`, in a pane you did not ask for. answer `y`
there. until you do, `C-h` loads the plugin and moves nothing, which from the
keyboard is indistinguishable from a binding that was never there.
`nav-parity.sh` looks for the answer in `~/.cache/zellij/permissions.kdl` and
fails while it is missing.

that also means smart-splits.nvim must not be lazy-loaded: `@pane-is-vim`
stays unset until the plugin loads, and until then tmux would move its own
pane on the first `C-h` in a fresh nvim.

two gaps in that plugin are filled here:

    tmux/.config/tmux/pane-owns-key.sh  `@pane-is-vim` only knows about nvim,
                                        and fzf owns C-j and C-k in ordinary
                                        shell panes. the old is_vim regex
                                        covered fzf by accident; here it is
                                        said. herdr covers the same case
                                        through the passthrough regex the
                                        shell configs export
    herdr-resize-pane.sh                the herdr plugin ships navigation
                                        actions but no resize actions, and a
                                        plain herdr binding on ctrl+arrows
                                        would take the keys before an nvim
                                        pane could resize its own splits.
                                        it also owns the unit: `herdr pane
                                        resize --amount` is a fraction of the
                                        split, not a cell count, so the 3 that
                                        smart-splits.nvim passes through reads
                                        as 300% and slams the split to its
                                        minimum -- nvim calls this script with
                                        `--mux-only` instead, and the step is
                                        3 cells in all three apps
    herdr-cycle-tab.sh                  herdr's next_tab takes one key, which
                                        C-a n already has, so C-a <Tab> needs
                                        a command of its own
    herdr-cycle-workspace.sh            the same, for the workspace level:
                                        next_workspace holds alt+j, so
                                        C-a j goes through this

each of the three herdr scripts has a `.ps1` twin next to it, which the
windows herdr config binds instead -- and layer 0 has a fourth twin there,
`herdr-navigate.ps1`, because the plugin that provides it here is linux and
macos only. see [windows](#windows).

no side wraps at the outer edge: `at_edge = "stop"` in nvim,
`@smart-splits_no_wrap` in tmux, and neither the herdr plugin nor the zellij one
wraps at all. anything else would make the edge depend on which app owns the
pane.

## after a fresh deploy

nvim installs the plugin, and the other two consume its checkout, so the order
matters once. `nav-setup.sh` is that order:

> nav-setup.sh

it runs `nvim --headless "+Lazy! install" +qa`, links herdr's plugin against
the checkout that produces, downloads zellij's `vim-zellij-navigator` at the
version and checksum pinned in the script, and reports how many actions herdr
ended up with -- four, or `ctrl+hjkl` is still dead. it is idempotent, so it is
also what to run after a `git pull` moved the pinned commit.

it stops short of restarting the herdr server. a running server picks up the
new plugin from `reload-config`, which the script does, but a changed prefix
or passthrough regex needs the server to go away and be relaunched from a
fresh shell -- and that closes every pane in the running session. on a fresh
deploy there is nothing to lose, so say so:

> nav-setup.sh --restart-server

## checking it has not drifted

> nav-parity.sh

it reads nvim's `keybindings.yaml`, starts a throwaway tmux server on a private
socket and asks it to `list-keys`, and reads both herdr configs, then reports
every row of the table above that is missing on a side that should have it. it
also diffs the keys block of `herdr/` against `.herdr-devcontainer/` -- herdr
has no include mechanism, so those keys are duplicated on purpose and nothing
but a check keeps them equal -- and the same block against `.herdr-windows/`
with the `command =` lines taken out, since there the same keys reach the
`.ps1` twins. and it verifies that the pinned commit, the checkout on disk and
herdr's plugin link still agree.

zellij is the one side it cannot ask. there is no `list-keys` there, and
`zellij setup --check` only says whether the file parses -- which is worth
having, since one misspelt key name takes the whole config down and not just
that line, but it is not an inventory. so its keys are read out of the KDL,
and to make up for that it is the one side checked in both directions: every
key its prefix mode binds, and every `ctrl` key its shared and locked blocks
bind, has to be a row of the table. a binding added to zellij alone is exactly
how it drifted out of this scheme in the first place, and it is the one kind of
drift that reading a config for named keys cannot see.

# claude code

`claude/` carries the four files of `~/.claude` that are configuration rather
than state -- `settings.json`, the `SessionStart` hook that reports the session
to herdr, the `prompt-pop` theme and the display options of the claude-hud
statusline:

    claude/.claude/settings.json
    claude/.claude/hooks/herdr-agent-state.sh
    claude/.claude/themes/prompt-pop.json
    claude/.claude/plugins/claude-hud/config.json

everything else in `~/.claude` -- sessions, history, `projects/`, the plugin
cache -- belongs to the machine, which is why the package is in `sd_unfolded`.
folded, `~/.claude` would become one symlink into this repository and all of
that would land in the working tree. claude code rewrites `settings.json` in
place rather than replacing it, so the link survives a `/theme` or a
`/plugin install` and the change shows up here as a diff.

nothing in the two files may name `/home/entwickler`: both the statusline
command and the hook are run through a shell, so they use `$HOME` and
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}` instead.

## plugins, once per machine

> claude-bootstrap.sh

`settings.json` names both halves of a plugin -- `extraKnownMarketplaces` says
where it comes from, `enabledPlugins` says it is on -- but declaring it does
not install it. since claude code 2.1.195 a plugin from an external source that
only a settings file enables is reported as not installed, and the cli does not
clone a marketplace it has only read about. so the two commands have to run
once:

> claude plugin marketplace add jarrodwatts/claude-hud
> claude plugin install claude-hud@claude-hud

`claude-bootstrap.sh` reads those two tables out of the packaged
`settings.json` and runs the pair for every plugin it finds, so declaring
another plugin in `settings.json` is the only edit a second one needs. both
commands are idempotent and neither rewrites `settings.json`; `-n` prints them
and runs nothing. restart claude code, or `/reload-plugins`, afterwards.

# herdr on another machine

a herdr window here can attach to the herdr server on another linux machine
over ssh: this machine draws the ui with its own theme and keybindings, and
the panes and agents run over there. two forms:

> herdr --remote <alias>                       one window, that server only
> herdr machine add <alias> --label <name>     saved: that server appears in
>                                              the sidebar next to the local one

`<alias>` is a `Host` in `ssh/.ssh/config`, which is what makes the target a
name instead of a user@address on every call. herdr wraps that config in one
of its own that adds keepalives, so none are set here.

the `ssh` package is that config and the agent it relies on:

    .ssh/config                          AddKeysToAgent, and the Host aliases
    .config/systemd/user/
      ssh-agent.service                  one agent per login, listening at
                                         $XDG_RUNTIME_DIR/ssh-agent.socket

the key has a passphrase, and herdr's saved machines connect in the background
where nothing can ask for one -- the machine shows "attention" instead. so the
agent holds the key: the first interactive `ssh <alias>` asks once and adds
it, and every connection after that, herdr's included, finds it there until
the agent stops. the three shells export SSH_AUTH_SOCK for the socket when it
exists and nothing has set one already, so a devcontainer's forwarded agent or
a desktop session's own is never displaced; shell-parity.sh checks the three
agree on it wherever the socket exists.

once per machine, after deploying:

> systemctl --user enable --now ssh-agent.service

and once per target -- it needs sshd running over there, and the key copied:

> ssh-copy-id <alias>
> herdr machine add <alias> --label <name>

`herdr machine add` runs in the foreground on purpose: it checks the herdr on
the far side, offers to install one to `~/.local/bin` there if it finds none,
and starts its server before saving the profile. after that, `herdr` alone
shows both machines. if a saved machine ever shows "attention", `herdr
--remote <alias>` shows the prompt it could not answer in the background.

the custom keys of this config (`C-a j`, `C-a Tab` and the resize keys) are
shell commands, and those run on the server side: against another machine
they work only if this repository is deployed there too.

# windows

the windows machine runs this repository natively, out of its own checkout at
`%USERPROFILE%\dotfiles`, and differs from the linux hosts in one package and
two mechanics. it has two launchers, and which one a machine uses is a question
about the account rather than about the packages: they end in the same layout.

> stow-deploy-windows.sh

the one to prefer, run from git bash. it deploys the set of `stow-deploy.sh`
with `herdr/` swapped for `.herdr-windows/`, the way a container swaps in
`.herdr-devcontainer/` (and hidden for the same reason, see
[devcontainer](#devcontainer)).

symlinks are the first mechanic, and what this launcher needs. msys *copies*
files instead of linking them unless `MSYS=winsymlinks:nativestrict` is set,
and creating a native link needs developer mode (settings > system > for
developers) or an elevated shell. the launcher sets the variable and probes for
the privilege before stow runs, and stops with that hint when it cannot; `-n`
needs neither.

a machine that had `herdr/` deployed before the swap has to let go of it
first, or stow aborts the whole run with "stowed to a different package":

> stow --dir ~/dotfiles --target ~ -D herdr

> deploy-windows-noadmin.ps1

the fallback for an account that may not create symlinks at all -- a work
machine that is neither its own administrator nor in developer mode, which is
what this one is. `-n`, `-List`, `-Remove` and package names work as with the
stow script; the policy-bypass call is in the script's header. two things need
no privilege and cover every package windows reads:

- a directory package -- `nvim`, `wezterm`, `komorebi`, `kmonad`, `scoop`,
  `nushell`, `yazi`, `fastfetch`, `bat`, `scripts` -- becomes an ntfs junction
  under the profile into the checkout: the folded link stow makes for it on
  linux.
- a single-file package is pointed at with the variable its tool reads,
  `STARSHIP_CONFIG` and `WHKD_CONFIG_HOME`. git gets a two-line `~\.gitconfig`
  that includes `git\.gitconfig` from the checkout, because tortoisegit and
  other libgit2 clients read the file and know nothing of `GIT_CONFIG_GLOBAL`.

what the two of them leave behind is the same, which is what lets one set of
configs serve both:

    stow-deploy-windows.sh              deploy-windows-noadmin.ps1
    ~\.config\<pkg>        symlink      ~\.config\<pkg>       junction
    ~\.local\bin\<file>    symlinks     ~\.local\bin          junction
    ~\.config\herdr\...    symlink      HERDR_CONFIG_PATH
    ~\.gitconfig           symlink      ~\.gitconfig          include stub
    ~\.config\starship...  symlink      STARSHIP_CONFIG

they write the same paths, so a machine keeps one of them at a time: undeploy
the other first, with `stow-deploy-windows.sh -D` or
`deploy-windows-noadmin.ps1 -Remove`. each reports the other's links as a
conflict with that hint rather than replacing them.

the packages the powershell script leaves on the linux side, and why, are
listed in its table. `claude` is one of them: `~\.claude` on windows is a
separate claude code install with its own settings and a powershell hook, where
this package's hook and status line are bash and bun.

## the herdr package

`herdr/` is written for a linux host: fish as the pane shell, and the custom
commands behind ctrl+arrows, `C-a <Tab>` and `C-a j/k` call bash scripts by
bare name through `/bin/sh -lc`. herdr on windows can run neither -- a missing
shell makes every new pane fail, and custom commands go through `cmd.exe /d
/c`. so the windows config names `pwsh` (herdr's own fallback is "PowerShell",
and its binary knows both `powershell.exe` and `pwsh.exe`) and binds `.ps1`
twins:

    scripts/.local/bin/herdr-resize-pane.ps1
    scripts/.local/bin/herdr-cycle-tab.ps1
    scripts/.local/bin/herdr-cycle-workspace.ps1
    scripts/.local/bin/herdr-navigate.ps1

same decisions as the `.sh` next to each, with `ConvertFrom-Json` in place of
jq, process names stripped of their `.exe` before the vim regex sees them, and
the resize fraction formatted culture-invariant. the fourth has no `.sh` here
because its original is not ours: layer 0 on linux is smart-splits.nvim's
bundled herdr plugin, whose manifest reads `platforms = ["linux", "macos"]` and
whose four actions run `bash scripts/herdr-navigate.sh` with jq. neither half
of that is available to herdr on windows, which runs a command through
`cmd.exe`, so `herdr-navigate.ps1` makes the plugin's decision itself -- vim in
the pane gets the key, otherwise the neighbouring pane gets the focus, and at
the edge of the grid the key falls back into the pane so that `ctrl+l` still
clears. they are called through pwsh
by full path under `%USERPROFILE%\.local\bin`, because nothing puts that
directory on the windows PATH; nvim's smart-splits spec calls the resize twin
the same way for its `--mux-only` case. that path is also why the powershell
script deploys `scripts` although most of it is bash -- the keys have to find
the twins where stow puts them. `nav-parity.sh` compares the keys block of
`.herdr-windows/` against `herdr/` with the `command =` and `type =` lines left
out, so the keys cannot drift while the mechanism behind them differs on
purpose.

the powershell script points `HERDR_CONFIG_PATH` at that file (herdr honours it
since 0.9.1) rather than junctioning `~\.config\herdr`: herdr writes its
socket, logs and session next to its config, and a junction would put all of it
in the checkout -- the same reason the stow deploys keep herdr unfolded. a
running server has to be restarted to see the variable (`herdr server stop`,
then launch again); `herdr server reload-config` re-reads only the file it
started with.

## where the tools look

nvim, nushell, scoop and fastfetch follow `XDG_CONFIG_HOME`, set in the user
environment to `%USERPROFILE%\.config` -- by hand after a stow deploy, by the
powershell script otherwise. komorebi and yazi have no xdg lookup at all and
need `KOMOREBI_CONFIG_HOME` and `YAZI_CONFIG_HOME`, and bat does not read it on
windows either, so `BAT_CONFIG_DIR` points at `%USERPROFILE%\.config\bat`
followed by one `bat cache --build` for the theme; the powershell script sets
those three the same way. variables written to the user environment reach
terminals opened after the deploy, not the one it ran in.

nvim keeps its data under `%LOCALAPPDATA%\nvim-data` rather than
`~/.local/share`, so `nav-setup.sh` does not apply here -- and neither does its
herdr half: that links a plugin this platform cannot load, which is why layer 0
is a twin instead. nothing on the windows side needs the smart-splits checkout,
so nothing there needs nvim.

what runs from wsl instead: `nu-regen-init.nu` (this nu spells `$nu.home-dir`
`home-path`), `claude-bootstrap.sh` (the windows jq emits CRLF, which leaves
a `\r` on the plugin name) and `nav-parity.sh` (tmux).

## junctions, and line endings

two things to know about a junction. git run inside `~\.config\nvim` does not
find the checkout, because windows reports the junction path as the working
directory and there is no `.git` above it -- run git in the checkout. and
whatever a tool writes into its junctioned directory lands in the checkout,
exactly as with a folded stow link; nushell's generated files are covered by
`.gitignore`, and `~\.local\bin` belongs to the repository entirely, so
anything else that wants a place in there wants `~\.local\bin` on the linux
side instead. a junction whose package moved inside the checkout is repaired by
the next run, like a stow link is.

`.gitattributes` pins every file to lf, so git for windows -- `core.autocrlf =
true` in its system config -- does not check the shell scripts out with crlf,
and an editor that saves crlf does not turn into a whole-file diff.

## ssh into the windows host from wsl

`ssh win` from the wsl distro reaches the windows account it runs under, for
files, `pwsh`, and everything a shell over there does. the account is not its
own administrator, so the openssh server windows ships as an optional feature
-- a system service on port 22, a firewall rule, `HKLM` -- is out of reach,
and two scripts stand in for it:

> windows-sshd-user.ps1 [-Install | -Status | -Stop]

the windows side. `-Install`, once, fetches the win32-openssh release zip into
`%LOCALAPPDATA%\Programs\OpenSSH-Win64` (the client windows ships has no
`sshd.exe`), makes a host key and an `sshd_config` under `~\.ssh\sshd`, and
checks the config with `sshd -t`. without a switch it starts `sshd.exe` as a
hidden process of the logged-on user, on port 2222, bound to the `vEthernet
(WSL ...)` adapter alone: nothing on the lan can reach it, and no firewall rule
is needed. a non-system sshd can log in only the account it runs as, with a
key, which is all this is for -- the wsl `~/.ssh/id_ed25519.pub` goes into
`~\.ssh\authorized_keys` on windows by hand. nothing autostarts it, because a
process of the session dies with the session and the wsl adapter it binds to
exists only while wsl runs; instead:

> windows-host-ssh-proxy.sh

the wsl side, a `ProxyCommand` like the devcontainer one (see [reaching a
devcontainer over ssh](#reaching-a-devcontainer-over-ssh)): before every
connection it runs the launcher through interop, which is a no-op while sshd
is up and a restart when the adapter's address moved, then pipes to that
address -- the default gateway of the distro, looked up rather than written
down. `~/.ssh/config.d/windows-host.conf` holds the block, per machine:

    Host win
        Port 2222
        User <windows account>
        IdentityFile ~/.ssh/id_ed25519
        IdentitiesOnly yes
        ProxyCommand ~/dotfiles/scripts/.local/bin/windows-host-ssh-proxy.sh %h %p

`HKLM:\SOFTWARE\OpenSSH\DefaultShell` is not writable either, so a session
lands in `cmd.exe`; `ssh win pwsh` gets the other one. wsl2 in nat mode is
assumed -- under `networkingMode=mirrored` the host is `127.0.0.1` and the
proxy's gateway lookup is the wrong address.

# devcontainer

the devcontainers of the projects here stow this repo and install neovim and
herdr, so both tools inside a container are the ones configured here. to open
one of them in the container:

> devcontainer-nvim.sh [options] [--] [nvim args...]
> devcontainer-herdr.sh [options] [--] [herdr args...]

herdr keeps a persistent server of its own, so where it is started matters:
run in the container, its session, its agents and its worktrees all live next
to the code they work on, inside the sandbox the devcontainer sets up.

both launchers only name their tool. everything they share lives in
`scripts/.local/lib/dotfiles/devcontainer-lib.sh`, which is sourced, not run:
it picks the
container, the remote user (`remoteUser` from the container's devcontainer
metadata) and the `/workspaces` folder. if several devcontainers are there to
choose from it lists them and asks, offering the one whose workspace holds the
current directory as the default. `--container` names one outright, `--dir`
overrides the start directory, `--list` shows what there is, `--help` explains
the rest.

stopped containers count. vs code shuts a devcontainer down with the last
window on it and a reboot leaves every one of them behind, so a container that
is merely not running is started rather than refused -- and one running
container is still picked silently, because stopped leftovers should not turn
that into a question. what `docker start` does not bring back are the
devcontainer.json lifecycle hooks (`postStartCommand` and friends): those
belong to vs code and the devcontainer cli, so the launcher says so when it
starts one. if a workspace needs them, open it in vs code or run
`devcontainer up` instead.

images count too. with no container for a project -- the first checkout of a
worktree, or a container removed after its config changed -- the `vsc-*`
images are offered next to the containers, and choosing one builds a container
from it. that build is `devcontainer up`, never a hand-written `docker run`:
the workspace mount, the sibling `firstx_` repository, the ssh directory, the
named volumes, the remote user and the lifecycle hooks are all in
devcontainer.json and nowhere else, and a container missing them would look
almost right, which is the worst way to be wrong.

the one thing an image cannot say is where its workspace is:
`devcontainer.local_folder` is a label on containers, never on images, and the
image name gives only the folder's *name*. so the launcher writes down every
workspace folder it sees, in
`${XDG_STATE_HOME:-~/.local/state}/devcontainer-launcher/workspaces`, and
resolves an image against that list -- exact match first, then a sibling of a
remembered folder, since worktrees sit next to each other. `--workspace PATH`
says it outright and it asks if it still cannot tell.

a container built in here is labelled with the *wsl* path of the workspace
while vs code labels its own with the *windows* path, so vs code will not adopt
it and would build a second one alongside. the launcher warns before it does
this. when vs code is going to open the project anyway, let vs code build it.

it also checks that the container's terminfo knows `$TERM` and falls back to
`xterm-256color` if it does not: a ghostty or wezterm `$TERM` reaches a plain
ubuntu image as an unknown terminal, and the display a full-screen tool then
draws is broken in ways whose message never mentions `$TERM`.

arguments are passed through unchanged and resolved inside the container,
relative to the start directory -- a host path is not translated. anything
starting with a dash needs a `--` first, so the launcher does not read it as
one of its own:

> devcontainer-nvim.sh -- --headless +qa
> devcontainer-herdr.sh -- --session firstx

`herdr/` is the herdr config for this machine, `.herdr-devcontainer/` the
one for a container: a different theme, a different accent and a
`DEVCONTAINER` badge in the tab bar, so the two instances are never mistaken
for each other. a second config is the only way to get that -- herdr has no
include mechanism and no project-local file. (since 0.9.1 it does honour a
`HERDR_CONFIG_PATH` variable, which is how the windows side gets its own
config, see [windows](#windows); the container keeps the stow route.)

that second package has to be a *hidden* directory. `stow */` matches no
dot-directory, so this machine deploys `herdr/` and ignores it; two visible
packages both providing `.config/herdr/config.toml` would instead make stow
abort the whole run -- every package, not just herdr -- with "existing
target is stowed to a different package". the container excludes `herdr`
from its stow list (`DOTFILES_STOW_EXCLUDE` in its Dockerfile) and stows
`.herdr-devcontainer` by name, unfolded: herdr writes its socket, its logs
and `session.json` into `~/.config/herdr`, and with the directory folded
into a symlink those writes would land in this repo.
`stow-deploy-devcontainer.sh` deploys exactly that set, for a
container whose `~/dotfiles` has moved on since the image was built.

to add a third tool, copy a launcher: source the library, set `dc_tool`, its
`dc_tool_hint` and a few `dc_examples`, then call `dc_main "$@"`.

since herdr 0.9.0 there is a second way in, and it does not go through a
launcher at all: `herdr machine add <ssh-target>` registers a container as a
*saved machine*, and its workspaces and agents then live in this machine's
herdr window, next to the local ones. the container needs an sshd and the
same herdr version for that -- the firstx devcontainer has both, see the
"herdr from the host" section of its `.devcontainer/README.md` -- and this
host needs a way to reach that sshd, see "reaching a devcontainer over ssh"
below.

which config governs what differs between the two. nested, through
`devcontainer-herdr.sh`, `.herdr-devcontainer/` is the whole config, theme and
badge included. as a saved machine the *client* supplies theme, sidebar and
keybindings, so that theme never renders and the `machine` token on the
sidebar row is the tell instead; what still comes from the container's config
is what its server decides -- the pane shell (`[terminal] default_shell`, which
is why that key is in there) and its update checks. `nav-parity.sh` compares
only the keys block of the two files, so both cases resolve the same
navigation scheme.

## a shell in any container

the launchers above are for *devcontainers*, and they know a lot about them:
the `devcontainer.local_folder` label, `remoteUser`, the workspace folder,
starting a stopped one. `dsh` is the other half of the question -- any running
container, picked from a list, with a shell in it:

> docker-shell.sh [options] [--] [command...]

aliased to `dsh` in all three shells. `-c` preselects, `-x` skips the picker
when the preselection leaves exactly one container, `-u` and `-w` override the
user and the working directory, `--help` explains the rest. with no command it
tries fish, then bash, then sh.

the defaults (`vscode` in `/workspaces/firstx-master`) name the container this
was written for, and every one of them is checked against whatever gets
picked: no such user, or no such directory, and it falls back to the
container's own and says so. so the defaults cost nothing anywhere else.

it is not a `dc_` launcher because it answers a different question and lists
containers the launchers filter out -- but if what you want is nvim or herdr
in *the* devcontainer, `devcontainer-nvim.sh` is still the one to reach for:
it starts a stopped container, `dsh` only lists running ones.

the obvious spelling of this is a pipeline into xargs:

> docker ps -q | xargs docker exec -it -u vscode -w /workspaces/firstx-master fish

which cannot work. xargs builds its command from stdin, so the child's stdin
is the pipe rather than the terminal, `-it` finds no tty, and the shell exits
at once. gnu xargs has `--open-tty` for exactly that, but a command
substitution is both shorter and portable, and is what the script does.

posix sh rather than a function in each shell config: it is one picker
reachable from three dialects, and the fzf preview has to be a command fzf can
re-run for every row anyway. the script is its own preview -- fzf calls it
back as `docker-shell.sh --preview <id>` -- which keeps the renderer next to
the picker instead of in a second file. in the list: enter opens the shell,
`^R` reloads it, `^L` follows the container's logs, `^Y` copies its id.

the preview zeroes the kitty keyboard protocol the way
`fish/.config/fish/functions/fzf.fish` does. that wrapper only covers a direct
`fzf` call from fish, and this script is reached from three shells, so it has
to do it for itself -- otherwise fish's key-release events arrive in fzf's
prompt as literal text like `102;1:3u`.

## a devcontainer in this herdr window

the same picker, for the other question: not a shell in a container, but a
container in *this* herdr:

> herdr-machine.sh [options]

it lists the running devcontainers, and registers the one you pick as a herdr
saved machine -- `herdr machine add`, with the ssh target worked out for you.
`-c`/`-x` preselect the way `dsh`'s do, `-n` says what it would run without
running it, `-l` overrides the sidebar label (default: the worktree the
container was built for), `-s` picks a named session on the far side.

why bother, when `dsh` already reaches into a container: herdr recognizes an
agent from the *foreground process* of a pane, so a pane holding
`docker exec ... claude` holds `docker`, and the agent panel stays empty. a
saved machine puts the agents next to the herdr server that owns them, inside
the container, and that server reports them properly -- states, session
identity, `herdr agent prompt`, all of it. (`HERDR_AGENT=claude docker exec
... claude` is the documented way to make the panel see a wrapped agent, and
it does work, but it hands over no session identity.)

the ssh target is derived rather than configured, and there are two shapes
it can take. preferred is `<worktree>.dc` -- the alias
`devcontainer-ssh-setup.sh` installs on this host (next section), which
reaches the container on the docker bridge by *name*: `ssh -G` is asked
whether that name resolves to the proxy, with the port and user this run
wants, and if so nothing about the container's ports matters. otherwise the
container's published port gives a `host:port`, and `ssh -G` is asked whether
any `Host` block in `~/.ssh/config` resolves to exactly that address, port and
user; a match wins because that is where the identity file lives, and only
when nothing matches does it fall back to a bare `ssh://user@host:port`. the
alias is preferred because it names the container rather than an address: a
rebuild changes the address, and a saved machine pointing at one goes stale.

the preview is the readiness check, and every probe in it is local docker or
local ssh config -- no dialing, so moving the cursor cannot hang on a network
timeout. it shows how the container is reached (the alias and its bridge
address, or the published port, or neither), whether sshd is up in there, the
container's herdr version against the 0.9.0 floor that saved machines need,
the target that would be used, whether it is already registered, and the
agents already running inside. two of those probes filter what they read
rather than trusting it: a failed `docker exec` prints "executable file not
found in $PATH" on *stdout*, so a container without herdr would otherwise
have that paragraph shown as its version.

the first connection is made by the script, in the foreground, on purpose.
herdr's own connects and reconnects are non-interactive -- a host key it has
never seen leaves the machine sitting in *Attention* instead of asking -- so
the script does the trust-on-first-use itself, and prints that the fingerprint
should match the one the container's `init-sshd.sh` logged when it started.

the container side needs an sshd and herdr 0.9.0 for any of this; the firstx
devcontainer has both, and its `.devcontainer/README.md` explains the sshd,
the key path and the per-worktree host key under "herdr from the host".

## reaching a devcontainer over ssh

the host side of the same story, done once per machine:

> devcontainer-ssh-setup.sh [-n]

after it, `ssh <worktree>.dc` reaches the running devcontainer built for that
worktree -- `ssh firstx-wa.dc`, `herdr machine add firstx-wa.dc` -- and that
is the target `herdr-machine.sh` registers.

why a name and not a port. a devcontainer's sshd could be *published* on a
host port, and that is how this started: `"appPort": ["127.0.0.1:2222:2222"]`
in devcontainer.json. but every worktree of a project shares one tracked
devcontainer.json, and a published port cannot be shared, so two worktree
containers running at once needed two different values of a line that is the
same file in both -- a permanent dirty diff per worktree and a conflict on
every sync from master. docker here is native to the distro, so a container's
address on the bridge (`172.17.0.x`) is reachable from wsl directly, and
nothing needs publishing at all.

what the script writes is small. `~/.ssh/config.d/devcontainers.conf` holds
one block:

    Host *.dc
        Port 2222
        User vscode
        IdentityFile ~/.ssh/id_ed25519
        IdentitiesOnly yes
        ProxyCommand .../devcontainer-ssh-proxy.sh %h %p

and `~/.ssh/config` gets `Include config.d/*.conf` as its first line -- first,
because an `Include` that follows a `Host` block belongs to that block. that
one insertion is the only edit to a hand-written file, a `config.bak-<date>`
is taken before it, and the include file is generated from the script, so
re-running the script is how it is updated. the block is *not* a stow package
on purpose: `~/.ssh` is the one directory here that should stay the machine's
own, and the ProxyCommand carries an absolute path anyway -- herdr's
background connections start from herdr, not from a login shell, so the
proxy cannot rely on `$PATH`.

the proxy, `devcontainer-ssh-proxy.sh`, is what makes the name stable. on
every connection it finds the running container whose
`devcontainer.local_folder` label ends in the worktree name -- the same
segment `herdr-machine.sh` lists and `dsh` shows, windows and wsl path forms
alike -- reads its bridge address, and hands the connection to `nc`. a
container that is stopped, rebuilt or replaced changes address; the name does
not, and neither does the saved machine that points at it. stdout of a
ProxyCommand *is* the connection, so everything the proxy has to say goes to
stderr, where ssh shows it as the reason the connection failed: "no running
devcontainer for worktree 'firstx-wa'" is the message when the container is
down.

there is no `HostKeyAlias` in that block, and that is deliberate. with no
`HostName`, the alias itself is the name ssh files the host key under
(`[firstx-wa.dc]:2222`, port-qualified because it is not 22), so
`firstx-wa.dc` and `firstx-master.dc` get separate `known_hosts` entries for
free -- and separate entries are only worth something if the keys differ,
which is why the firstx devcontainer keeps its host key in a volume named
per worktree (`firstx-sshd-hostkeys-${localWorkspaceFolderBasename}`). a
connection that lands in the wrong container -- the proxy picking the wrong
one, say -- then fails as a host key mismatch instead of silently opening the
wrong workspace. (`HostKeyAlias %h` would have been the alternative, but
`HostKeyAlias` is not among the keywords that take tokens.) one accept per
worktree, on the first connection, which `herdr-machine.sh` does in the
foreground.

what it checks before writing, and refuses on: `nc` (the openbsd netcat
ubuntu ships), the proxy on `$PATH` (stow-deploy.sh first), and that the
bridge gateway docker reports is an interface of *this* distro. under docker
desktop it is not -- the bridge lives in the desktop vm -- and the whole path
is unavailable; a published port and `herdr-machine.sh`'s fallback still
work there. two things are lost with the bridge and worth knowing: the
container is no longer reachable from windows as `localhost:2222` (a side
effect of the published port that nothing relied on), and a container that
still publishes the port is reached on the bridge all the same -- the rebuild
only drops the publish, so nothing has to happen in a particular order.

the script also reports what the published-port scheme left behind -- a
`Host` block that resolves to `127.0.0.1:2222`, a saved machine whose target
is not a `.dc` name -- with the commands to remove them, and removes neither:
those are hand-written config and client state.

## rebuilding a devcontainer

the third picker, and the one that replaces containers instead of reaching
into them:

> devcontainer-rebuild.sh [options] [project...]

it looks one level under `~/SWProjekte` and `/mnt/c/SWProjekte` (`--roots`
elsewhere) for anything carrying a devcontainer config, and rebuilds what you
pick with `devcontainer up --remove-existing-container` -- the command vs
code's *rebuild container* runs. `tab` selects several, `^A` takes all, `-a`
skips the picker entirely, `--no-cache` is *rebuild without cache*, `-n`
prints the exact command per project and runs nothing, `-y` skips the
question.

the question is asked because a rebuild deletes the container it replaces, and
anything running in there -- an agent mid-task, a herdr server -- goes with
it. the confirmation names the projects whose container is *running* rather
than just listing what was picked.

the point of care in this script is identity. vs code stamps
`devcontainer.local_folder` with the path *it* opened, so on windows that is
`c:\SWProjekte\x` -- lower-case drive, backslashes -- while the same extension
writes `devcontainer.config_file` and the workspace bind mount the way the
docker host sees them, `/mnt/c/SWProjekte/x`. all three were read off a
container this machine's vs code built. the cli left to itself writes the wsl
spelling for every one of them, and the result is not a visible failure: the
old container stays, a second one appears, and vs code builds its own again on
the next attach. so a project that already has a container is rebuilt under
that container's own labels, and only a project without one falls back to the
rule (`--label-style windows|wsl|auto`). where two containers exist for one
folder -- exactly the mess above -- the preview says so and the preferred
spelling decides which one is replaced.

`--mount-workspace-git-root false` is in there for the same reason: it is the
cli's own convenience, mounting the git root and treating the opened folder as
a subpath, which the extension does not do. these worktrees are their own git
root, so it changes nothing today and everything the day a subfolder is
opened.

builds run one at a time. two concurrent devcontainer builds are what took wsl
down in firstx-master's
`.devcontainer/issues/wsl-memory-and-container-sharing.md`, and a rebuild is
the memory-hungry half of that. each one's output is streamed and kept under
`~/.local/state/devcontainer-rebuild`, and the summary at the end says which
project ended up in which container -- or which log to read.

the preview is the pre-flight: the config's `name`, every container docker has
for that folder with the label each carries, and the `devcontainer up` command
that would run, one flag per line. nothing in it builds or starts anything, so
moving the cursor stays cheap.
