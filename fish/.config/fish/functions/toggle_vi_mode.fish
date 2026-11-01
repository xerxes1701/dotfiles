# Switches between vi and default key bindings for this shell only (-g), so
# every new shell starts with the normal setting. Bound to alt-m in
# fish_user_key_bindings.fish.
function toggle_vi_mode
    if test "$fish_key_bindings" = fish_vi_key_bindings
        set -g fish_key_bindings fish_default_key_bindings
    else
        set -g fish_key_bindings fish_vi_key_bindings
    end
    commandline -f repaint
end
