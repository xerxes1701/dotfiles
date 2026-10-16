# git-win (scripts package) completes as git. The completion's own git calls
# go through the wsl-git shim too, so a checkout on a Windows drive is read by
# git.exe -- fast, and the only git that can read a worktree git.exe made.
# gw, an alias, wraps git-win and so completes the same way.
function __git_win_complete
    set -lx PATH $HOME/.local/lib/wsl-git $PATH
    set -lx WSL_GIT_NO_STDIN 1
    complete -C "git "(string replace -r '^\S+\s*' '' -- (commandline -cp))
end
complete -c git-win -f -a '(__git_win_complete)'
