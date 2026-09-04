# content

contains verisioned dotfiles. files can be mirrored under ~ via `gnu stow`

# usage

create all sym links

> stow \*/

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
