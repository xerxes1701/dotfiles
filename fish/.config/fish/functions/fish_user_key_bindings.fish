# fish reruns this after every switch of binding set, which is what keeps
# alt-m alive across toggle_vi_mode. alt-m is free in niri, ghostty and herdr;
# fish's own alt-v is edit-in-editor, so it is not used here.
function fish_user_key_bindings
    for mode in default insert visual
        bind -M $mode alt-m toggle_vi_mode
    end
end
