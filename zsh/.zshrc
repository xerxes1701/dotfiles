# Sections below mirror fish/.config/fish/config.fish and
# nushell/.config/nushell/{env,config}.nu. Keep them in the same order with the
# same contents; shell-parity.sh reports any drift.

# ===== env =====

export EDITOR=nvim
export VISUAL=nvim
export BAT_THEME="Catppuccin Macchiato"
export MANROFFOPT="-c"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export BUN_INSTALL="$HOME/.bun"

# fzf. Moved here out of .zshrc_fzf so fish and nushell can share them; the
# zsh-only keybindings and completion helpers stay in that file.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --preview-window=right:60% --preview '[ -f {} ] && bat --style=numbers --color=always {} || eza --tree --color=always --icons=always {} | head -200'"

# herdr's side of the unified navigation scheme. smart-splits.nvim's herdr
# plugin knows to leave ctrl+hjkl to a pane that holds nvim, but nothing else;
# fzf binds ctrl+j and ctrl+k itself and runs in ordinary shell panes, so it
# has to be named. tmux covers the same case in ~/.config/tmux/pane-owns-key.sh.
# The plugin runs on the herdr server, which inherits this from the shell that
# launched it -- so a `herdr server stop` and relaunch is what picks up a change.
export SMART_SPLITS_HERDR_PASSTHROUGH_RE='^fzf$'

# Ollama. Server-side settings: they apply to an `ollama serve` started from a
# shell, not to the systemd unit, which needs its own drop-in. q8_0 halves the
# KV cache against the f16 default, which is what fits 16k context alongside
# qwen3.5:9b's 6.14 GiB of weights on an 8 GB card.
export OLLAMA_CONTEXT_LENGTH=16384
export OLLAMA_KV_CACHE_TYPE=q8_0
export OLLAMA_KEEP_ALIVE=30m

# ===== path =====

# `typeset -U` keeps $path deduplicated, so re-sourcing never grows it.
typeset -U path
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.dotnet/tools" "$BUN_INSTALL/bin" $path)

# ===== tool init =====

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

# ===== aliases: listing =====

alias ls='eza --color=always --icons=always'
alias ll='eza -al --group-directories-first --icons=always'
alias la='eza -a --color=always --group-directories-first --icons=always'
alias lf='eza -lf --color=always --icons=always | grep -v /'
alias lh='eza -dl .* --group-directories-first --icons=always'
alias lt='eza -al --sort=modified --icons=always'
alias ld='eza -lD --icons=always'
alias tree='eza --tree --color=always --icons=always'

# ===== aliases: navigation =====

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

# ===== aliases: tools =====

alias g='git'
alias v='nvim'
alias vim='nvim'
alias vid='neovide'
alias code='code --password-store="gnome-libsecret"'
alias c='code'
alias y='yazi'
alias f='fzf --preview "bat {} --force-colorization"'
alias neogit='nvim -c :Neogit'
alias conf='tmuxinator start conf'

# Pick a running container with fzf and open a shell in it. A script in
# scripts/, not three copies of a function: it is the same picker in all three
# shells, and the fzf preview has to be a command fzf can re-run per row.
alias dsh='docker-shell.sh'

# Open a file, a URL or piped content in a real browser. A script for the same
# reason as dsh -- and because under WSL this is nowhere near a one-liner:
# explorer.exe has to be named with its full path and handed a windows path,
# which wslpath refuses to make from a relative one, i.e. from exactly what
# `fzf` prints. Takes targets or stdin: `br datei.html`, `fzf | br`.
alias br='browse.sh'

alias cls='clear'

# RDP to the Windows box. The password is piped in from 1Password rather than
# passed as /p:, which would leave it in shell history and in
# /proc/<pid>/cmdline for anything that can run ps.
alias rdp='op read "op://Personal/My Microsoft Account/password" | xfreerdp3 /v:192.168.178.22 /d:MicrosoftAccount /u:michael-gawlik@outlook.com /from-stdin +dynamic-resolution +clipboard /cert:ignore'

# Debian/Ubuntu ship bat as batcat. On Arch the real binary is `bat`, so only
# bridge the name when that is actually the situation. (The old unconditional
# `alias bat=batcat` shadowed a working bat with a command that does not exist.)
if ! command -v bat >/dev/null && command -v batcat >/dev/null; then
  alias bat='batcat'
fi

# ===== aliases: system =====

alias update='sudo cachyos-rate-mirrors && sudo pacman -Syu'
alias mirror='sudo cachyos-rate-mirrors'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'
alias jctl='journalctl -p 3 -xb'
alias grubup='sudo grub-mkconfig -o /boot/grub/grub.cfg'

# ===== functions =====

ssh-agent-start() {
  eval "$(ssh-agent -s)"
  ssh-add "$HOME/.ssh/id_rsa"
}

# ===== shell-specific =====

bindkey -s '\e' '^U'

# fzf keybindings, completion and preview settings.
# Sourced by absolute path -- the old relative `source .zshrc_fzf` only resolved
# when $PWD happened to be $HOME, so it failed on every other startup.
[ -f "$HOME/.zshrc_fzf" ] && source "$HOME/.zshrc_fzf"

# zgen is optional: it is not installed everywhere, and sourcing it unguarded
# printed "no such file or directory" on every startup.
#
# oh-my-zsh used to be picked up here the same way. It is gone on purpose: it
# gets sourced at the very bottom, after the alias sections above, and its
# lib/theme-and-appearance.zsh and lib/directories.zsh redefine ls, l, ll and
# la -- silently replacing the eza aliases with plain `ls` on any machine that
# happens to have oh-my-zsh installed (a devcontainer base image, for one).
[ -f "$HOME/.zgen/zgen.zsh" ] && source "$HOME/.zshrc_zgen"
