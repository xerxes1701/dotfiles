#!/usr/bin/env bash
# Report drift between the fish, nushell and zsh configs.
#
# Rather than regex-parsing three different config syntaxes, this asks each
# shell to enumerate itself. That also catches what fish silently inherits
# from /usr/share/cachyos-fish-config/cachyos-config.fish.
#
# Exits non-zero if any unallowlisted difference is found.
# Intentional differences live in scripts/shell-parity.allow.

set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
allow_file="$here/shell-parity.allow"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

SHELLS=(fish nu zsh)
status=0

# Child shells inherit our environment, which would make every env/PATH check
# falsely report agreement. Run them with a clean slate instead, so we measure
# what each config actually sets.
clean() { env -i HOME="$HOME" TERM="${TERM:-xterm}" USER="${USER:-$(id -un)}" \
               PATH=/usr/local/bin:/usr/bin:/bin "$@"; }

NUCFG=(--config "$HOME/.config/nushell/config.nu" --env-config "$HOME/.config/nushell/env.nu")

# Functions expected to exist in every shell.
FUNCS=(ssh-agent-start)

# Environment variables expected to agree across every shell.
ENVVARS=(EDITOR VISUAL BAT_THEME MANPAGER MANROFFOPT BUN_INSTALL
         FZF_DEFAULT_COMMAND FZF_CTRL_T_COMMAND FZF_ALT_C_COMMAND FZF_DEFAULT_OPTS
         OLLAMA_CONTEXT_LENGTH OLLAMA_KV_CACHE_TYPE OLLAMA_KEEP_ALIVE)

# PATH entries expected in every shell.
PATHENTRIES=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.dotnet/tools" "$HOME/.bun/bin")

# --- allowlist -------------------------------------------------------------

is_allowed() { # shell name
    [ -f "$allow_file" ] || return 1
    grep -qxF -e "$1:$2" -e "*:$2" "$allow_file"
}

# Collapse the shell-specific quoting so expansions can be compared.
normalize() {
    sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//" \
        -e "s/^'\(.*\)'$/\1/" -e 's/^"\(.*\)"$/\1/' \
        -e 's/[[:space:]]\{1,\}/ /g' \
        -e 's/\^\([a-zA-Z]\)/\1/g'
}

# --- per-shell collection --------------------------------------------------
# Each writes "<name>\t<expansion>" to $tmp/aliases.<shell>

collect_fish() {
    # `alias` prints: alias NAME 'BODY'
    clean fish -i -c 'alias' 2>/dev/null |
        sed -n "s/^alias \([^ ]*\) \(.*\)$/\1\t\2/p"
}

collect_nu() {
    # nu -c does not load config.nu on its own, so point it at the file.
    clean nu "${NUCFG[@]}" -c 'scope aliases | each {|a| $"($a.name)(char tab)($a.expansion)" } | to text' 2>/dev/null
    # `..`-style helpers must be `def`s in nu, not aliases -- include them too,
    # minus nushell'\''s own internals and zoxide'\''s private commands.
    clean nu "${NUCFG[@]}" -c 'scope commands | where type == "custom" | get name | to text' 2>/dev/null |
        grep -v '^__' | grep -vx -e banner -e pwd | sed 's/$/\t<def>/'
}

collect_zsh() {
    # `alias` prints: NAME=BODY
    clean zsh -i -c 'alias' 2>/dev/null |
        sed -n "s/^\([^=]*\)=\(.*\)$/\1\t\2/p"
}

for s in "${SHELLS[@]}"; do
    "collect_$s" | sort -u >"$tmp/aliases.$s"
    cut -f1 "$tmp/aliases.$s" | sort -u >"$tmp/names.$s"
done

cat "$tmp"/names.* | sort -u >"$tmp/names.all"

# --- 1. aliases present in some shells but not others ----------------------

printf '== aliases ==\n'
missing_report=$tmp/missing
: >"$missing_report"

while IFS= read -r name; do
    [ -n "$name" ] || continue
    absent=()
    for s in "${SHELLS[@]}"; do
        grep -qxF "$name" "$tmp/names.$s" || absent+=("$s")
    done
    # Present everywhere, or present nowhere -- nothing to say.
    [ ${#absent[@]} -eq 0 ] && continue
    [ ${#absent[@]} -eq ${#SHELLS[@]} ] && continue
    # Names checked in the functions section below are not aliases everywhere.
    printf '%s\n' "${FUNCS[@]}" | grep -qxF "$name" && continue
    # Allowlisted for every shell it is missing from?
    exempt=1
    for s in "${absent[@]}"; do
        is_allowed "$s" "$name" || exempt=0
    done
    [ "$exempt" -eq 1 ] && continue
    printf '  %-14s missing from: %s\n' "$name" "${absent[*]}" >>"$missing_report"
done <"$tmp/names.all"

if [ -s "$missing_report" ]; then
    cat "$missing_report"
    status=1
else
    printf '  all aliases agree (modulo the allowlist)\n'
fi

# --- 2. same name, different expansion -------------------------------------

printf '\n== expansions ==\n'
differs=$tmp/differs
: >"$differs"

while IFS= read -r name; do
    [ -n "$name" ] || continue
    exempt=0
    for s in "${SHELLS[@]}"; do
        is_allowed "$s" "$name" && exempt=1
    done
    [ "$exempt" -eq 1 ] && continue

    bodies=()
    for s in "${SHELLS[@]}"; do
        b=$(awk -F'\t' -v n="$name" '$1==n {print $2; exit}' "$tmp/aliases.$s" | normalize)
        [ -n "$b" ] && bodies+=("$s=$b")
    done
    [ ${#bodies[@]} -lt 2 ] && continue
    # Some names must be functions in some shells (nushell mis-parses aliases
    # containing a pipe, and has no `&&`). Presence is still checked above;
    # comparing a function body against an alias string is not meaningful.
    printf '%s\n' "${bodies[@]}" | grep -q '=<def>$' && continue
    first=${bodies[0]#*=}
    for entry in "${bodies[@]}"; do
        if [ "${entry#*=}" != "$first" ]; then
            {
                printf '  %s\n' "$name"
                for e in "${bodies[@]}"; do printf '      %-5s %s\n' "${e%%=*}" "${e#*=}"; done
            } >>"$differs"
            break
        fi
    done
done <"$tmp/names.all"

if [ -s "$differs" ]; then
    cat "$differs"
    status=1
else
    printf '  all shared aliases expand identically\n'
fi

# --- 3. functions -----------------------------------------------------------

printf '\n== functions ==\n'
for fn in "${FUNCS[@]}"; do
    absent=()
    clean fish -i -c "functions -q $fn" 2>/dev/null || absent+=(fish)
    clean nu "${NUCFG[@]}" \
       -c "if (scope commands | where name == '$fn' | is-empty) { exit 1 }" \
       >/dev/null 2>&1 || absent+=(nu)
    clean zsh -i -c "typeset -f $fn" >/dev/null 2>&1 || absent+=(zsh)
    if [ ${#absent[@]} -eq 0 ]; then
        printf '  %-16s ok\n' "$fn"
    else
        printf '  %-16s missing from: %s\n' "$fn" "${absent[*]}"
        status=1
    fi
done

# --- 4. environment variables ----------------------------------------------

printf '\n== env ==\n'
for var in "${ENVVARS[@]}"; do
    fv=$(clean fish -i -c "echo \$$var" 2>/dev/null | normalize)
    nv=$(clean nu "${NUCFG[@]}" -c "\$env.$var? | default ''" 2>/dev/null | normalize)
    zv=$(clean zsh -i -c "echo \$$var" 2>/dev/null | normalize)
    if [ "$fv" = "$nv" ] && [ "$nv" = "$zv" ] && [ -n "$fv" ]; then
        printf '  %-12s ok  (%s)\n' "$var" "$fv"
    else
        printf '  %-12s DIFFERS  fish=%s | nu=%s | zsh=%s\n' \
            "$var" "${fv:-<unset>}" "${nv:-<unset>}" "${zv:-<unset>}"
        status=1
    fi
done

# --- 5. PATH ----------------------------------------------------------------

printf '\n== path ==\n'
clean fish -i -c 'for p in $PATH; echo $p; end' 2>/dev/null >"$tmp/path.fish"
clean nu "${NUCFG[@]}" -c '$env.PATH | to text'  2>/dev/null >"$tmp/path.nu"
clean zsh -i -c 'print -l $path'                 2>/dev/null >"$tmp/path.zsh"

for entry in "${PATHENTRIES[@]}"; do
    absent=()
    for s in "${SHELLS[@]}"; do
        grep -qxF "$entry" "$tmp/path.$s" || absent+=("$s")
    done
    if [ ${#absent[@]} -eq 0 ]; then
        printf '  %-28s ok\n' "$entry"
    else
        printf '  %-28s missing from: %s\n' "$entry" "${absent[*]}"
        status=1
    fi
done

for s in "${SHELLS[@]}"; do
    dupes=$(sort "$tmp/path.$s" | uniq -d | tr '\n' ' ')
    if [ -n "${dupes// /}" ]; then
        printf '  duplicate entries in %-5s %s\n' "$s:" "$dupes"
        status=1
    fi
done

printf '\n'
[ "$status" -eq 0 ] && printf 'shells are in sync.\n' || printf 'drift found (see above).\n'
exit "$status"
