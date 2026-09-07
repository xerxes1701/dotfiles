#!/usr/bin/env nu
#
# Regenerate nushell's zoxide and starship init files.
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
# Run this after installing or upgrading zoxide or starship:
#     nu scripts/nu-regen-init.nu

# starship only sets $env.PROMPT_COMMAND, which an autoload dir handles fine.
let autoload = ($nu.user-autoload-dirs | first)
mkdir $autoload
starship init nu | save -f ($autoload | path join "starship.nu")
print $"wrote ($autoload)/starship.nu"

# zoxide's init defines commands and a PWD hook, and those do NOT take effect
# from an autoload dir -- it has to be `source`d, as zoxide's own docs say. So
# it goes next to config.nu, which sources it by name.
# NOT `$nu.config-path | path dirname`: config.nu is a stow symlink, so that
# resolves back into the dotfiles repo and would commit generated output.
let cfgdir = ($nu.home-dir | path join ".config" "nushell")
zoxide init nushell | save -f ($cfgdir | path join "zoxide.nu")
print $"wrote ($cfgdir)/zoxide.nu"
