# config.nu
#
# Installed by:
# version = "0.111.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

alias ll = ls -l
alias g = git
alias c = code
alias f = fzf --preview 'batcat {} --force-colorization --theme="Catppuccin Mocha"'
alias vim = nvim
alias vid = neovide
alias cls = clear
alias bat = batcat
alias y = yazi

alias lf = eza -lf --color=always --icons=always | grep -v
alias lh = eza -dl .* --group-directories-first --icons=always
alias lzl = eza -al --group-directories-first --icons=always
alias lz = eza --color=always --icons=always
alias lt = eza -al --sort=modified --icons=always
alias ld = eza -lD --icons=always
alias tree = eza --tree --color=always --icons=always

source ~/.config/nushell/.zoxide.nu

$env.PATH ++= ['~/.dotnet/tools']

# workaround for https://github.com/nushell/nushell/issues/5585 (nushell scrolls on any key in wezterm wsl)
$env.config.shell_integration.osc133 = false
$env.config.show_banner = false
$env.config.buffer_editor = "nvim"
