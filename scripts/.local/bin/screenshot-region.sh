#!/bin/sh
# Screenshot a region of a frozen screen, copy it, and open it in satty.
# niri's mod+shift+s runs it.
#
# slurp alone draws its selection over the live screen, and grim captures only
# after the mouse is released: a video has moved on by then, and a dropdown or
# context menu is gone, because slurp's overlay takes the focus and an app
# closes its open menu when it loses it. So the screen is captured first:
# wayfreeze grabs every output on the keypress, while the menu is still open,
# and shows that still image on top. slurp then selects over the still image,
# and grim captures it from there.
#
# wayfreeze runs its --after-freeze-cmd with sh -c as its own child and never
# exits by itself, so that command ends by killing its parent, which unfreezes
# the screen. satty opens only after that, or it would sit under the frozen
# image. The file travels in SHOT, not spliced into the command, so its quoting
# cannot break. Esc in slurp leaves the file empty and opens nothing.

SHOT=$(mktemp --suffix=.png) || exit 1
export SHOT
trap 'rm -f "$SHOT"' EXIT

wayfreeze --hide-cursor --after-freeze-cmd 'g=$(slurp) && grim -g "$g" "$SHOT"; kill $PPID'

[ -s "$SHOT" ] || exit 0
wl-copy -t image/png < "$SHOT"
satty -f "$SHOT"
