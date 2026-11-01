# Hand fish's vim mode to starship, which draws it as a band at the start of
# the prompt line (see starship.toml), like the vim band of Claude Code's
# status line: "vim off" with the default bindings, else the mode. Exactly one
# STARSHIP_VIM_* variable is set, its value the label; the variable picks the
# band's colour.
#
# Handlers rather than a wrapped fish_prompt, so this works whatever order it
# loads in relative to `starship init`. Changing mode sets fish_bind_mode
# before the bindings' repaint-mode, and with no fish_mode_prompt (starship
# removes it) that repaint redraws the whole prompt, band included.
status is-interactive; or return

set -g __starship_vim_vars STARSHIP_VIM_OFF STARSHIP_VIM_NORMAL STARSHIP_VIM_INSERT \
    STARSHIP_VIM_VISUAL STARSHIP_VIM_REPLACE

function __starship_vim_mode --on-variable fish_bind_mode --on-variable fish_key_bindings --on-event fish_prompt
    set -e $__starship_vim_vars
    switch "$fish_key_bindings"
        case fish_vi_key_bindings fish_hybrid_key_bindings
            switch "$fish_bind_mode"
                case default
                    set -gx STARSHIP_VIM_NORMAL Normal
                case insert
                    set -gx STARSHIP_VIM_INSERT Insert
                case visual
                    set -gx STARSHIP_VIM_VISUAL Visual
                case replace_one replace
                    set -gx STARSHIP_VIM_REPLACE Replace
                case '*'
                    # A mode without a band of its own: grey, by its name.
                    set -gx STARSHIP_VIM_OFF $fish_bind_mode
            end
        case '*'
            set -gx STARSHIP_VIM_OFF 'vim off'
    end
end

# Exported only for starship: erased while a command runs, so no program the
# command line starts (a nested shell's prompt, yazi's starship header) shows
# a mode that isn't its own.
function __starship_vim_mode_clear --on-event fish_preexec
    set -e $__starship_vim_vars
end
