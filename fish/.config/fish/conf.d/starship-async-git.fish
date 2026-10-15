# Render starship's git_status in the background so a slow `git status` never
# blocks the prompt. The result lands in $STARSHIP_GIT_STATUS, which
# starship.toml shows through an env_var module in git_status's place.
#
# At most one `git status` runs per shell. Prompts that come up while it runs
# only queue a single rerun, so a burst of commands can't pile up scans.
status is-interactive; or return
type -q starship; or return

set -g __async_git_dir (mktemp -d -t starship-git.XXXXXX)
set -g __async_git_pid       # the running job, also its process group (see setsid)
set -g __async_git_job_root  # the repo that job is scanning
set -g __async_git_rerun 0   # a prompt came up while the job was running
set -g __async_git_root      # the repo the shown status belongs to
set -g __async_git_at_prompt 0

# Config for the background run only. A long timeout costs nothing off the
# prompt's critical path. It also draws the git band's counters, a coloured
# sign and count per kind of change on the band's `surface`, which
# starship.toml passes through as it is; starship-git-status.toml has the
# same, for the shells that render it just before the prompt. The colours are
# the status line's muted ones, as in claude/.claude/status-band/git-status.toml.
# \U000F19B2 and \U000F19B3 are Nerd Font's thin arrows up and down
# (md-arrow_up_thin, md-arrow_down_thin).
string join \n -- \
    'command_timeout = 300000' \
    'palette = "one_half_dark"' \
    '[git_status]' \
    'format = "$conflicted$staged$renamed$modified$deleted$typechanged$untracked$stashed$ahead_behind"' \
    'conflicted = "[ =${count}](bg:surface fg:orange)"' \
    'staged = "[ +${count}](bg:surface fg:green)"' \
    'renamed = "[ »${count}](bg:surface fg:purple)"' \
    'modified = "[ ~${count}](bg:surface fg:yellow)"' \
    'deleted = "[ -${count}](bg:surface fg:red)"' \
    'typechanged = "[ t${count}](bg:surface fg:purple)"' \
    'untracked = "[ ?${count}](bg:surface fg:subtext)"' \
    'stashed = "[ ≡${count}](bg:surface fg:blue)"' \
    'ahead = "[ \U000F19B2${count}](bg:surface fg:cyan)"' \
    'behind = "[ \U000F19B3${count}](bg:surface fg:cyan)"' \
    'diverged = "[ \U000F19B2${ahead_count}](bg:surface fg:cyan)[ \U000F19B3${behind_count}](bg:surface fg:cyan)"' \
    'up_to_date = ""' \
    '[palettes.one_half_dark]' \
    'surface = "#3E4451"' \
    'subtext = "#AFB3BB"' \
    'red = "#D5A7AB"' \
    'orange = "#C9AE93"' \
    'yellow = "#D7C198"' \
    'green = "#A1BA8E"' \
    'cyan = "#8CBBC1"' \
    'blue = "#8FB7D7"' \
    'purple = "#C9A7D3"' >$__async_git_dir/starship.toml

# Walk up to the nearest .git (a file for worktrees and submodules). string
# rather than `path dirname`, which a devcontainer's older fish may lack.
function __async_git_find_root
    set -l dir $PWD
    while test -n "$dir"
        test -e $dir/.git; and echo $dir; and return
        set dir (string replace -r '/[^/]*$' '' -- $dir)
    end
    return 1
end

function __async_git_spawn
    set -g __async_git_job_root $__async_git_root
    set -g __async_git_rerun 0
    # On WSL, the git in ~/.local/lib/wsl-git (scripts package) goes first on
    # the scan's PATH: it hands a repository on a Windows drive to Windows'
    # git.exe, which reads NTFS fast, and the rest to Linux's git.
    # (A `set -l` inside the if would end with it.)
    set -l path $PATH
    if set -q WSL_DISTRO_NAME; and test -x $HOME/.local/lib/wsl-git/git
        set path $HOME/.local/lib/wsl-git $PATH
    end
    set -lx PATH $path
    # GIT_OPTIONAL_LOCKS=0: starship runs plain `git status`, which holds
    # .git/index.lock for the whole scan and would make your own git commands
    # fail with "index.lock: File exists" until it finishes.
    # setsid: fish runs background jobs in its own foreground process group,
    # so without it Ctrl-C would hit the scan and __async_git_stop couldn't
    # kill git along with sh.
    GIT_OPTIONAL_LOCKS=0 STARSHIP_CONFIG=$__async_git_dir/starship.toml command setsid sh -c \
        'starship module git_status >"$1/$$.tmp" 2>/dev/null; mv "$1/$$.tmp" "$1/$$"; kill -USR1 "$2"' \
        sh $__async_git_dir $fish_pid </dev/null &
    set -g __async_git_pid $last_pid
    # Keep the job out of `jobs`, starship's job count and fish's "has ended" notice.
    disown $last_pid
end

function __async_git_stop
    set -q __async_git_pid[1]; or return
    kill -- -$__async_git_pid 2>/dev/null
    set -g __async_git_pid
end

function __async_git_prompt --on-event fish_prompt
    set -g __async_git_at_prompt 1
    set -l root (__async_git_find_root)
    if test "$root" != "$__async_git_root"
        # Another repo's status is wrong, not just stale: drop it, and don't
        # make the new repo wait for a scan of the old one.
        set -e STARSHIP_GIT_STATUS
        set -g __async_git_root $root
        __async_git_stop
    end
    test -n "$root"; or return
    # A dead job that never reported (e.g. killed from outside) doesn't count.
    if set -q __async_git_pid[1]; and kill -0 $__async_git_pid 2>/dev/null
        set -g __async_git_rerun 1
    else
        __async_git_spawn
    end
end

function __async_git_preexec --on-event fish_preexec
    set -g __async_git_at_prompt 0
end

function __async_git_done --on-signal SIGUSR1
    # Results of jobs stopped by __async_git_stop are ignored.
    set -l file $__async_git_dir/$__async_git_pid
    set -q __async_git_pid[1]; and test -f $file; or return
    set -l value (string collect <$file)
    rm -f $file
    set -g __async_git_pid
    # A separate test, and the x in front, because the status can be a lone
    # `!` (modified files), which test takes for its negation operator.
    if test "$__async_git_job_root" = "$__async_git_root"; and test "x$value" != "x$STARSHIP_GIT_STATUS"
        set -gx STARSHIP_GIT_STATUS $value
        test $__async_git_at_prompt = 1; and commandline -f repaint
    end
    # During a command, the next prompt starts a fresh scan anyway.
    if test $__async_git_rerun = 1 -a $__async_git_at_prompt = 1
        __async_git_spawn
    end
end

function __async_git_cleanup --on-event fish_exit
    __async_git_stop
    rm -rf $__async_git_dir
end
