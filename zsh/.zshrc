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

# ssh-agent.service, from the ssh package, listens here. Exported only when the
# socket exists and nothing has set SSH_AUTH_SOCK already -- a devcontainer
# forwards the host's agent and a desktop session may bring its own -- so this
# never displaces an agent, it only supplies one where there was none.
#
# XDG_RUNTIME_DIR is unset on a WSL distro that logs in without pam_systemd,
# while the socket is there all the same, so /run/user/<uid> -- the path the
# unit's %t expands to -- is the fallback.
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
  agent_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  [ -S "$agent_dir/ssh-agent.socket" ] && export SSH_AUTH_SOCK="$agent_dir/ssh-agent.socket"
  unset agent_dir
fi

# ===== path =====

# `typeset -U` keeps $path deduplicated, so re-sourcing never grows it.
typeset -U path
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.dotnet/tools" "$BUN_INSTALL/bin" $path)

# ===== tool init =====

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

# starship.toml leaves git_status to $STARSHIP_GIT_STATUS (see its header).
# fish renders that in the background; zsh renders it here, just before each
# prompt -- where git_status ran before, at the same cost. Its config sits
# next to starship.toml. GIT_OPTIONAL_LOCKS=0 keeps the scan from holding
# .git/index.lock against your own git commands.
# On WSL, the git in ~/.local/lib/wsl-git (scripts package) goes first on
# the scan's PATH: it hands a repository on a Windows drive to Windows'
# git.exe, which reads NTFS fast, and the rest to Linux's git.
__starship_git_status() {
  local config=${${STARSHIP_CONFIG:-$HOME/.config/starship.toml}:h}/starship-git-status.toml path=$PATH
  [[ -n $WSL_DISTRO_NAME && -x $HOME/.local/lib/wsl-git/git ]] && path=$HOME/.local/lib/wsl-git:$PATH
  export STARSHIP_GIT_STATUS=$(PATH=$path GIT_OPTIONAL_LOCKS=0 STARSHIP_CONFIG=$config starship module git_status 2>/dev/null)
}
precmd_functions+=(__starship_git_status)

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
alias gw='git-win'
alias v='nvim'
alias vim='nvim'
alias vid='neovide'
alias code='code --password-store="gnome-libsecret"'
alias c='code'
# yazi's header draws the starship prompt (starship.yazi), so the git counters of
# this shell's directory must not reach it.
alias y='env -u STARSHIP_GIT_STATUS yazi'
alias f='fzf --preview "bat {} --force-colorization"'
alias neogit='nvim -c :Neogit'
alias conf='tmuxinator start conf'
alias cl='claude'
alias clc='claude --continue'
alias clr='claude --resume'
alias dn='dotnet'
alias dnb='dotnet build'
alias dnr='dotnet run'
alias dnt='dotnet test'
alias dnpa='dotnet package add'
alias dnap='dotnet package add'
alias dnn='dotnet new'
alias dnsa='dotnet sln add'
alias dnpub='dotnet publish'
alias dnto='dotnet tool'

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

# Save the image on the clipboard as a file: `pimg` for ./clipboard-<stamp>.png,
# `pimg images/` for that directory, `pimg name.png` for exactly that file. A
# script for the same reason as br: on WSL the clipboard is only reachable
# through Windows PowerShell, and elsewhere through wl-paste or xclip.
alias pimg='paste-image.sh'

# Copy the previous command line to the clipboard: run something, then `cpl`.
# copy-text.sh does the copying, for the same reason as pimg; the line itself
# comes from here, because every shell keeps its history its own way. From
# $history rather than `fc -ln -1`, which prints a newline in the command as
# a literal \n.
cpl() { print -r -- "${history[$((HISTCMD - 1))]}" | copy-text.sh; }

# Open a path in Windows Explorer, like `e` in the Windows PowerShell profile:
# a directory as a folder window, a file with its default program, `.` when no
# path is given. A script for the same reason as br.
alias e='e.sh'

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

# Jump to a FirstX worktree (gz) or to a branch (gsw), like the functions of the
# same names in the Windows PowerShell profile. The fzf pick is done by gz.sh
# and gsw.sh, which print the directory to go to; only the `cd` has to live in
# the shell, because a script cannot change its parent's directory.
gz() {
  local dir
  dir=$(gz.sh "$@") || return
  [ -n "$dir" ] && cd -- "$dir"
}

gsw() {
  local dir
  dir=$(gsw.sh "$@") || return
  [ -n "$dir" ] && cd -- "$dir"
}

# ===== shell-specific =====

bindkey -s '\e' '^U'

# git-win (scripts package) completes as git; gw, an alias, completes as what
# it expands to. The completion's own git calls go through the wsl-git shim
# too, so a checkout on a Windows drive is read by git.exe -- fast, and the
# only git that can read a worktree git.exe made. WSL_GIT_NO_STDIN keeps
# git.exe from swallowing the pipes _git runs it in.
__git_win_complete() {
  local -x PATH=$HOME/.local/lib/wsl-git:$PATH WSL_GIT_NO_STDIN=1
  local service=git
  _git "$@"
}
(( $+functions[compdef] )) && compdef __git_win_complete git-win

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
