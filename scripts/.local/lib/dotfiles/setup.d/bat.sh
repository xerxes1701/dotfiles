# bat: debian and ubuntu ship the binary as batcat. The shells alias it, but
# an alias does not reach fzf's previews or nvim, so link it under its own
# name. Only where bat is missing and batcat is there: on arch, windows, or a
# release that renames it back, there is nothing to do.

setup_needed() { link_needed bat batcat; }
setup_apply()  { link_apply bat batcat; }
