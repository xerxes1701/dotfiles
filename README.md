# content

contains verisioned dotfiles. files can be mirrored under ~ via `gnu stow`

# usage

each top level directory is one `gnu stow` package holding the paths it owns
relative to `~`, so `nvim/.config/nvim/init.lua` is linked as
`~/.config/nvim/init.lua`. deploy them with:

> scripts/stow-deploy.sh

and inside a devcontainer, which replaces two of the packages with its own:

> scripts/stow-deploy-devcontainer.sh

both are `stow */` with the two things that instruction gets wrong. stow folds
a package into a single symlink when its target directory does not exist yet,
so `~/.config/fish` and `~/.config/herdr` become links into this repository
and everything those tools write there -- fisher's plug-ins, herdr's socket,
logs and session -- lands in the working tree; the scripts stow both unfolded.
and a container leaves `git` and `herdr` out, in favour of the packages it
replaces them with.

`-n` shows what would happen and changes nothing, `--list` the packages a
script deploys, `-R` re-creates the links after a package lost a file, `-D`
removes them, `--target` deploys somewhere other than `~`, `--help` explains
the rest. either script refuses to run in the other's environment. naming
packages deploys only those:

> scripts/stow-deploy.sh nvim tmux

nushell needs `nu scripts/nu-regen-init.nu` once per machine afterwards, see
[shells](#shells).

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

dependency of nvim-treesitter

install

> sudo apt install tree-sitter-cli

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
body contains a pipe. `scripts/shell-parity.sh` knows about that case.

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

> scripts/shell-parity.sh

it asks each shell to enumerate its own aliases, functions, env vars and PATH
in a clean environment, then reports anything defined in one shell but not the
others. intentional differences are listed with a reason in
`scripts/shell-parity.allow`; it exits non-zero on anything else.

nushell needs one extra step, because it cannot `source` a pipeline the way
`zoxide init fish | source` does. run this once per machine, and again after
upgrading zoxide or starship:

> nu scripts/nu-regen-init.nu

that writes starship's init into `~/.config/nushell/autoload/` (picked up
automatically) and zoxide's into `~/.config/nushell/zoxide.nu` (sourced by
name from config.nu -- zoxide's defs and PWD hook do not take effect from an
autoload dir). both are generated and machine-local, deliberately not tracked
here: the previous setup committed a `zoxide init` dump that went stale
whenever zoxide was upgraded.

# devcontainer

the devcontainers of the projects here stow this repo and install neovim and
herdr, so both tools inside a container are the ones configured here. to open
one of them in the container:

> scripts/devcontainer-nvim.sh [options] [--] [nvim args...]
> scripts/devcontainer-herdr.sh [options] [--] [herdr args...]

herdr keeps a persistent server of its own, so where it is started matters:
run in the container, its session, its agents and its worktrees all live next
to the code they work on, inside the sandbox the devcontainer sets up.

both launchers only name their tool. everything they share lives in
`scripts/devcontainer-lib.sh`, which is sourced, not run: it picks the
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

> scripts/devcontainer-nvim.sh -- --headless +qa
> scripts/devcontainer-herdr.sh -- --session firstx

`herdr/` is the herdr config for this machine, `.herdr-devcontainer/` the
one for a container: a different theme, a different accent and a
`DEVCONTAINER` badge in the tab bar, so the two instances are never mistaken
for each other. a second config is the only way to get that -- herdr reads
only `~/.config/herdr/config.toml`, with no include mechanism, no
config-path variable and no project-local file.

that second package has to be a *hidden* directory. `stow */` matches no
dot-directory, so this machine deploys `herdr/` and ignores it; two visible
packages both providing `.config/herdr/config.toml` would instead make stow
abort the whole run -- every package, not just herdr -- with "existing
target is stowed to a different package". the container excludes `herdr`
from its stow list (`DOTFILES_STOW_EXCLUDE` in its Dockerfile) and stows
`.herdr-devcontainer` by name, unfolded: herdr writes its socket, its logs
and `session.json` into `~/.config/herdr`, and with the directory folded
into a symlink those writes would land in this repo.
`scripts/stow-deploy-devcontainer.sh` deploys exactly that set, for a
container whose `~/dotfiles` has moved on since the image was built.

to add a third tool, copy a launcher: source the library, set `dc_tool`, its
`dc_tool_hint` and a few `dc_examples`, then call `dc_main "$@"`.
