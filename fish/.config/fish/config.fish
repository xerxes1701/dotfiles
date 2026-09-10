if test -e /usr/share/cachyos-fish-config/cachyos-config.fish
  source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Sections below mirror nushell/.config/nushell/{env,config}.nu and zsh/.zshrc.
# Keep them in the same order with the same contents; shell-parity.sh
# reports any drift.

# ===== env =====

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx BAT_THEME "Catppuccin Macchiato"
set -gx MANROFFOPT "-c"
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -gx BUN_INSTALL "$HOME/.bun"

# fzf. These were previously zsh-only (in .zshrc_fzf); they are plain env vars,
# so all three shells can share them. The preview is deliberately POSIX-ish --
# fzf runs it through $SHELL, which may be any of the three.
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
set -gx FZF_DEFAULT_OPTS "--height=40% --layout=reverse --preview-window=right:60% --preview '[ -f {} ] && bat --style=numbers --color=always {} || eza --tree --color=always --icons=always {} | head -200'"

# herdr's side of the unified navigation scheme. smart-splits.nvim's herdr
# plugin knows to leave ctrl+hjkl to a pane that holds nvim, but nothing else;
# fzf binds ctrl+j and ctrl+k itself and runs in ordinary shell panes, so it
# has to be named. tmux covers the same case in ~/.config/tmux/pane-owns-key.sh.
# The plugin runs on the herdr server, which inherits this from the shell that
# launched it -- so a `herdr server stop` and relaunch is what picks up a change.
set -gx SMART_SPLITS_HERDR_PASSTHROUGH_RE '^fzf$'

# Ollama. Read by the ollama *server*, not the client, so these apply only to an
# `ollama serve` started from a shell -- the systemd unit needs the same values
# in a `systemctl edit ollama` drop-in. Sized for the 8 GB RTX 4060: qwen3.5:9b
# is 6.14 GiB of weights, leaving ~1.5 GiB, so the q8_0 KV cache (1 byte per
# element against f16's 2) is what keeps 16k context on the GPU. Verify with
# `ollama ps` -- PROCESSOR must read 100% GPU.
set -gx OLLAMA_CONTEXT_LENGTH 16384
set -gx OLLAMA_KV_CACHE_TYPE q8_0
set -gx OLLAMA_KEEP_ALIVE 30m

# ===== path =====

# fish_add_path skips entries already in $PATH, so this is idempotent -- unlike
# the `set -gx PATH $PATH ...` appends it replaces, which re-added on every
# nested shell and collided with CachyOS's universal fish_user_paths.
fish_add_path -g $HOME/.local/bin $HOME/.cargo/bin $HOME/.dotnet/tools $BUN_INSTALL/bin

# ===== tool init =====

if status is-interactive
  zoxide init fish | source
  starship init fish | source
  fzf --fish | source
end

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
alias cls='clear'

# RDP to the Windows box. The password is piped in from 1Password rather than
# passed as /p:, which would leave it in shell history and in
# /proc/<pid>/cmdline for anything that can run ps.
alias rdp='op read "op://Personal/My Microsoft Account/password" | xfreerdp3 /v:192.168.178.22 /d:MicrosoftAccount /u:michael-gawlik@outlook.com /from-stdin +dynamic-resolution +clipboard /cert:ignore'

# Debian/Ubuntu ship bat as batcat. On Arch the real binary is `bat`, so only
# bridge the name when that is actually the situation.
if not type -q bat; and type -q batcat
  alias bat='batcat'
end

# ===== aliases: system =====

alias update='sudo cachyos-rate-mirrors && sudo pacman -Syu'
alias mirror='sudo cachyos-rate-mirrors'
alias cleanup='sudo pacman -Rns (pacman -Qtdq)'
alias jctl='journalctl -p 3 -xb'
alias grubup='sudo grub-mkconfig -o /boot/grub/grub.cfg'

# ===== functions =====

function ssh-agent-start --description 'Start an ssh-agent and load the default key'
  eval (ssh-agent -c)
  ssh-add $HOME/.ssh/id_rsa
end

# ===== shell-specific =====

# functions/fzf.fish  -- wrapper disabling the kitty keyboard protocol
# fish_plugins        -- fisher-managed plugins

# Colour theme, from the catppuccin/fish fisher plugin. `theme choose` sets the
# fish_color_* variables globally for this session; global beats universal in
# fish's scope lookup, so this wins over whatever a machine happens to have in
# its fish_variables. That is the point: unlike `fish_config theme save`, which
# the README used to tell you to run by hand, nothing machine-local has to stay
# in sync -- the theme lives in this file and travels with the repository.
#
# The name is the file name the plugin installs. Upstream renamed the themes to
# lower case with a hyphen; the old "Catppuccin Mocha" now fails with
# "No such theme". Guarded, so a checkout without the plugin installed does not
# error on every prompt.
if status is-interactive; and test -f $__fish_config_dir/themes/catppuccin-mocha.theme
  fish_config theme choose catppuccin-mocha
end
