# env.nu -- loaded before config.nu.
#
# Sections mirror fish/.config/fish/config.fish and zsh/.zshrc; keep them in
# the same order with the same contents. scripts/shell-parity.sh reports drift.

# ===== env =====

$env.EDITOR = "nvim"
$env.VISUAL = "nvim"
$env.BAT_THEME = "Catppuccin Macchiato"
$env.MANROFFOPT = "-c"
$env.MANPAGER = "sh -c 'col -bx | bat -l man -p'"
$env.BUN_INSTALL = ($nu.home-dir | path join ".bun")

# fzf. Previously zsh-only (in .zshrc_fzf); plain env vars, so all three shells
# share them. nushell has no `fzf --nu` integration upstream, so unlike fish and
# zsh it gets the settings but not the keybindings.
$env.FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git"
$env.FZF_CTRL_T_COMMAND = $env.FZF_DEFAULT_COMMAND
$env.FZF_ALT_C_COMMAND = "fd --type d --hidden --follow --exclude .git"
$env.FZF_DEFAULT_OPTS = "--height=40% --layout=reverse --preview-window=right:60% --preview '[ -f {} ] && bat --style=numbers --color=always {} || eza --tree --color=always --icons=always {} | head -200'"

# ===== path =====

# Built with `path join` rather than a literal "~/..." string: nushell does not
# tilde-expand inside a quoted list element, so the old `$env.PATH ++= ['~/...']`
# never resolved to a real directory.
$env.PATH = (
    $env.PATH
    | split row (char esep)
    | prepend [
        ($nu.home-dir | path join ".local" "bin")
        ($nu.home-dir | path join ".cargo" "bin")
        ($nu.home-dir | path join ".dotnet" "tools")
        ($env.BUN_INSTALL | path join "bin")
    ]
    | uniq
)
