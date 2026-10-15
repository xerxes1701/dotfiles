# Loads ~/.config/bash/config.bash, the port of config.fish. This file only
# exists because Debian's and Ubuntu's stock ~/.bashrc already sources it, so
# the bash package can stay out of a .bashrc that differs per distro. Where the
# stock .bashrc has no such hook (CachyOS, Git Bash), add the line below to it.
[ -f "$HOME/.config/bash/config.bash" ] && . "$HOME/.config/bash/config.bash"
