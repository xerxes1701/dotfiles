# fd: debian and ubuntu ship the binary as fdfind; fzf in the shells and
# telescope call fd. Same rule as bat.sh: only where fd is missing and fdfind
# is there.

setup_needed() { link_needed fd fdfind; }
setup_apply()  { link_apply fd fdfind; }
