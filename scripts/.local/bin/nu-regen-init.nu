#!/usr/bin/env nu
#
# Regenerate nushell's zoxide, starship and atuin init files.
#
# fish and zsh can init these inline (`zoxide init fish | source`), but nushell
# cannot `source` a pipeline -- `source` needs a path known at parse time. So we
# generate the files instead and drop them in a user autoload dir, which nushell
# loads automatically at startup (see `$nu.user-autoload-dirs`).
#
# The output is generated, machine-local and NOT tracked in this repo; that is
# deliberate. The previous setup checked a `zoxide init` dump into git as
# .zoxide.nu, which silently went stale whenever zoxide was upgraded.
#
# Run this after installing or upgrading zoxide, starship or atuin:
#     nu-regen-init.nu            (in ~/.local/bin once scripts is deployed)

# starship only sets $env.PROMPT_COMMAND, which an autoload dir handles fine.
let autoload = ($nu.user-autoload-dirs | first)
mkdir $autoload
starship init nu | save -f ($autoload | path join "starship.nu")
print $"wrote ($autoload)/starship.nu"

# atuin sets hooks and keybindings on $env.config, which an autoload dir also
# handles -- and, unlike a `source` by name, a machine without atuin simply has
# no file there instead of a nushell that fails to start. A stale file from an
# uninstalled atuin is removed for the same reason. --disable-ai: Atuin AI has
# no nushell widget, and `?` is left to nushell.
let atuin_init = ($autoload | path join "atuin.nu")
if (which atuin | is-not-empty) {
    atuin init nu --disable-ai | save -f $atuin_init
    print $"wrote ($atuin_init)"
} else if ($atuin_init | path exists) {
    rm $atuin_init
}

# zoxide's init defines commands and a PWD hook, and those do NOT take effect
# from an autoload dir -- it has to be `source`d, as zoxide's own docs say. So
# it goes next to config.nu, which sources it by name.
# NOT `$nu.config-path | path dirname`: config.nu is a stow symlink, so that
# resolves back into the dotfiles repo and would commit generated output.
let cfgdir = ($nu.home-dir | path join ".config" "nushell")
zoxide init nushell | save -f ($cfgdir | path join "zoxide.nu")
print $"wrote ($cfgdir)/zoxide.nu"
