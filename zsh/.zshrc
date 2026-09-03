# Sections below mirror fish/.config/fish/config.fish and
# nushell/.config/nushell/{env,config}.nu. Keep them in the same order with the
# same contents; scripts/shell-parity.sh reports any drift.

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
alias cls='clear'

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

# oh-my-zsh and zgen are optional: neither is installed here right now, and
# sourcing them unguarded printed "no such file or directory" on every startup.
if [ -d "$HOME/.oh-my-zsh" ]; then
  export ZSH="$HOME/.oh-my-zsh"
  ZSH_THEME=""   # starship draws the prompt
  plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
  source "$ZSH/oh-my-zsh.sh"
fi

[ -f "$HOME/.zgen/zgen.zsh" ] && source "$HOME/.zshrc_zgen"
