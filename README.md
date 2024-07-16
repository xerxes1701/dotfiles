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

## fzf
command-line fuzzy finder
[fzf github page](https://github.com/junegunn/fzf)

### install
use latetest binary release. replace existing.

### configuration
see `.zshrc_fzf

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

(eza github page)[https://github.com/eza-community/eza]

install
> sudo apt install eza
