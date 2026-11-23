# git aliases that run `al run git <name>` (git/.gitconfig: del, main,
# review, ...) complete like it: `git del b --rem<TAB>` as
# `al run git del b --rem`. The commands live in al/.config/al/aliases/git.toml.
function __al_git_own_command
    set -l tokens (commandline -xpc)
    set -q tokens[2]; or return 1
    string match -q -- '!al run git *' (git config --get alias.$tokens[2] 2>/dev/null)
end
complete -c git -n __al_git_own_command -f -a '(__al_complete al run)'
