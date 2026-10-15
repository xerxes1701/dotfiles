#!/bin/sh
# Browse the journal entries in ~/journal with fzf, rendered by glow in the
# preview. The entries are written by the `/mg-journal` Claude Code skill.

set -u

self=${0##*/}
dir=${JOURNAL_DIR:-$HOME/journal}

err() { printf '%s: %s\n' "$self" "$*" >&2; }

case ${1:-} in
    -h|--help)
        cat <<EOF
usage: $self [query]

lists the entries in $dir in fzf, newest first, with the entry rendered
by glow as preview. the query is matched against the date and the
section headings of each entry.

  enter    read the entry in glow's pager
  ctrl-e   open the entry in \$EDITOR
  ctrl-u/d scroll the preview half a page up/down
  ctrl-b/f scroll the preview a page up/down
  ctrl-/   toggle the preview
EOF
        exit 0
        ;;
esac

command -v fzf >/dev/null 2>&1 || { err "fzf is not on PATH"; exit 1; }
command -v glow >/dev/null 2>&1 || { err "glow is not on PATH"; exit 1; }
[ -d "$dir" ] || { err "$dir does not exist"; exit 1; }

cd "$dir" || exit 1

# One line per entry: the date, then the "## " headings, which fzf can match.
for f in $(ls -r -- *.md 2>/dev/null); do
    topics=$(sed -n 's/^## \(.*\)/\1/p' "$f" | paste -sd '|' | sed 's/|/ · /g')
    printf '%s\t%s\n' "${f%.md}" "$topics"
done |
    fzf --with-shell='sh -c' --delimiter='\t' --nth=1,2 --query="${1:-}" \
        --no-sort --tiebreak=index --prompt='journal> ' \
        --height=100% --layout=default \
        --preview='CLICOLOR_FORCE=1 COLORTERM=truecolor glow --style=dark --width=$FZF_PREVIEW_COLUMNS {1}.md' \
        --preview-window='up,80%,wrap,border-bottom' \
        --bind='enter:execute(glow --pager {1}.md)' \
        --bind='ctrl-e:execute(${EDITOR:-nvim} {1}.md)' \
        --bind='ctrl-/:toggle-preview' \
        --bind='ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down' \
        --bind='ctrl-b:preview-page-up,ctrl-f:preview-page-down'
