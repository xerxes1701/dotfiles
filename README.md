# content

contains verisioned dotfiles. files can be mirrored under ~ via `gnu stow`

# usage

create sym links
> stow .

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

note: binary is named batcat. aliased as `bat` in `.zshrc`

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
> fish_config theme save "Catppuccin Mocha"

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
