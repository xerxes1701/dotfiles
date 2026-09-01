function fzf --wraps fzf --description 'fzf with the kitty keyboard protocol disabled'
    # fzf does not implement the kitty keyboard protocol (junegunn/fzf#3208),
    # but fish 4.x enables it, so key-release events leak into fzf's prompt as
    # literal text like "102;1:3u". Zero the flags for the duration of the run;
    # fish re-enables them when it takes the reader back.
    # Written to /dev/tty so it never pollutes fzf's captured stdout.
    test -t 2 && printf '\e[=0;1u' >/dev/tty
    command fzf $argv
end
