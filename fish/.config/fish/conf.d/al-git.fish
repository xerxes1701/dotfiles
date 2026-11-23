# git aliases that run `al run git <name>` (git/.gitconfig: delete, main,
# review, ...), and their short forms that name them (re = review), complete
# like it: `git del b --rem<TAB>` as `al run git del b --rem`. The commands
# live in al/.config/al/aliases/git.toml.
function __al_git_own_command
    set -l tokens (commandline -xpc)
    set -q tokens[2]; or return 1
    set -l name $tokens[2]
    for i in 1 2 3
        set -l value (git config --get alias.$name 2>/dev/null); or return 1
        string match -q -- '!al run git *' $value; and return 0
        string match -qr -- '^[\w-]+$' $value; or return 1
        set name $value
    end
    return 1
end
complete -c git -n __al_git_own_command -f -a '(__al_complete al run)'
