# fish reruns this after every switch of binding set, which is what keeps
# alt-m alive across toggle_vi_mode. alt-m is free in niri, ghostty and herdr;
# fish's own alt-v is edit-in-editor, so it is not used here.
function fish_user_key_bindings
    for mode in default insert visual
        bind -M $mode alt-m toggle_vi_mode
    end
    # atuin's search, set here rather than by its init in config.fish: that runs
    # before fzf's ctrl-r would be replaced and before any switch of binding
    # set, both of which would leave fish's or fzf's binding in its place.
    if functions -q _atuin_search
        for mode in default insert
            bind -M $mode ctrl-r _atuin_search
            bind -M $mode up _atuin_bind_up
        end
    end
end
