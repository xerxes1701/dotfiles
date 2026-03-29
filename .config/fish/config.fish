if test -e /usr/share/cachyos-fish-config/cachyos-config.fish
  source /usr/share/cachyos-fish-config/cachyos-config.fish
end

if status is-interactive

  zoxide init fish | source
  starship init fish | source

  alias neogit='nvim -c :Neogit'

  alias lf='eza -lf --color=always --icons=always | grep -v /'
  alias lh='eza -dl .* --group-directories-first --icons=always'
  alias ll='eza -al --group-directories-first --icons=always'
  alias ls='eza -alf --color=always --sort=size --icons=always | grep -v /'
  alias ls='eza --color=always --icons=always'
  alias lt='eza -al --sort=modified --icons=always'
  alias ld='eza -lD --icons=always'

  alias tree='eza --tree --color=always --icons=always'

  export EDITOR=nvim

  alias conf='tmuxinator start conf'
  alias g='git'
  alias y='yazi'
  # Check if 'bat' is NOT a command AND 'batcat' IS a command
  if not type -q bat; and type -q batcat
    alias bat='batcat'
  end
  alias cls='clear'

  set -gx BAT_THEME "Catppuccin Macchiato"
  set -gx PATH $PATH $HOME/.dotnet/tools
  set -gx PATH $PATH $HOME/.local/bin

  function ssh-agent-start
    eval $(ssh-agent -c)
    ssh-add /home/xerxes/.ssh/id_rsa
  end 
end
