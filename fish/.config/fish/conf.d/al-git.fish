# git del / git delete run `al run git del…` (aliases in git/.gitconfig), so
# they complete like it: `git del b --rem<TAB>` as `al run git del b --rem`.
# The commands live in al/.config/al/aliases/git.toml.
function __al_git_own_command
    set -l tokens (commandline -xpc)
    contains -- "$tokens[2]" del delete
end
complete -c git -n __al_git_own_command -f -a '(__al_complete al run)'
