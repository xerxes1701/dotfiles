#!/usr/bin/env bash
# Install the tools this repository needs, picked from a list, together with
# whatever they need installed first.
#
# Deploying a package puts its config in place, not the tool that reads it.
# tools.toml says, per tool, where it belongs, the ways it can be installed --
# the platform's package manager, an alternate one like paru, cargo, npm or
# flatpak, or a script of its own -- what it needs first, and what to do after
# its packages. Its header explains the format. This script finds the manager
# of the machine it runs on:
#
#   cachyos/arch  pacman
#   ubuntu/debian apt
#   windows       winget, from git bash
#
# and installs each tool picked the first way that works here: the platform's
# manager when it has every one of the tool's packages, else the other ways in
# the order the tool lists them.
#
# A tool that installs through paru, cargo, npm or flatpak needs the tool that
# provides that command, and a tool's `needs` name more. Both are resolved
# before anything is installed, and what was not picked is proposed along with
# what was: on a plain arch, picking devcontainer proposes paru, which builds
# from the aur and so proposes git and base-devel, and installs them in that
# order. A tool counts as there when it is installed and its setup step done:
# rustup without a toolchain gives no working cargo.
#
# It is meant for a machine that has nothing yet, so it needs bash and awk and
# nothing else: the pick is an fzf multi-select when fzf is there and a
# numbered menu when it is not, and tools.toml is read by the small TOML
# reader below rather than by a tool that would itself need installing first.
#
# --conf reads another tools.toml: a project outside this repository lists its
# own tools in this format and installs them with this script. Its scripts run
# in the directory that file is in, so they can call scripts of their own.

set -uo pipefail

self=$(basename -- "$0")

# readlink -f, so this still finds the repository when the script is reached
# through the symlink that stowing `scripts` puts in ~/.local/bin. This file
# lives in scripts/.local/bin, three levels below the repository.
root=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../../.." && pwd) \
    || exit 1
conf=$root/scripts/.local/lib/dotfiles/tools.toml

# Same rule as the other scripts here: colors for a terminal only, and never
# against NO_COLOR (https://no-color.org) or TERM=dumb.
if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && { [ -t 1 ] || [ -t 2 ]; }; then
    c_bold=$(printf '\033[1m');         c_dim=$(printf '\033[2m')
    c_ok=$(printf '\033[1;38;5;108m');  c_bad=$(printf '\033[1;38;5;174m')
    c_warn=$(printf '\033[33m');        c_off=$(printf '\033[0m')
else
    c_bold= c_dim= c_ok= c_bad= c_warn= c_off=
fi

die() {
    printf '%s%s: error:%s %s\n' "$c_bad" "$self" "$c_off" "$1" >&2
    shift
    for hint in "$@"; do printf '%s  %s%s\n' "$c_dim" "$hint" "$c_off" >&2; done
    exit 1
}
warn() { printf '%s%s: warning:%s %s\n' "$c_warn" "$self" "$c_off" "$1" >&2; }

run() {
    printf '%s$ %s%s\n' "$c_dim" "$*" "$c_off"
    [ "$dry" = 1 ] || "$@"
}

# A container is usually root and often has no sudo.
as_root() { if [ "$(id -u)" = 0 ]; then run "$@"; else run sudo "$@"; fi; }

usage() {
    cat <<EOF
usage: $self [options] [tool...]

Install the tools listed in $conf
that belong on this platform, picked from a list, and what they need first.

  -a, --all            every tool for this platform, without asking which.
  -c, --conf FILE      another tools.toml.
  -l, --list           list the tools for this platform, how each would be
                       installed and what it needs, and exit.
  -m, --manager NAME   pacman, apt or winget instead of the detected one.
  -n, --dry-run        print the commands and scripts, run nothing.
  -s, --setup          only the setup steps of the tools here, install nothing.
  -y, --yes            do not ask before installing.
  -h, --help           this.

Named tools are installed without the list, e.g. $self nvim tmux.
EOF
    exit 0
}

all=0 list=0 dry=0 yes=0 setup_only=0 manager=''
while [ $# -gt 0 ]; do
    case $1 in
        -a | --all)     all=1; shift ;;
        -c | --conf)    [ -n "${2:-}" ] || die "$1 needs a value" 'a tools.toml'
                        conf=$2; shift 2 ;;
        --conf=*)       conf=${1#*=}; shift ;;
        -l | --list)    list=1; shift ;;
        -m | --manager) [ -n "${2:-}" ] || die "$1 needs a value" 'pacman, apt or winget'
                        manager=$2; shift 2 ;;
        --manager=*)    manager=${1#*=}; shift ;;
        -n | --dry-run) dry=1; shift ;;
        -s | --setup)   setup_only=1; shift ;;
        -y | --yes)     yes=1; shift ;;
        -h | --help)    usage ;;
        --)             shift; break ;;
        -?*)            die "unknown option $1" "$self --help" ;;
        *)              break ;;
    esac
done
wanted=("$@")

[ -r "$conf" ] || die "cannot read $conf"
conf_dir=$(cd -- "$(dirname -- "$conf")" && pwd) || exit 1

# --- platform --------------------------------------------------------------

# Git Bash is msys; WSL is a linux host with the distro's own manager.
detect_manager() {
    if [ -n "${MSYSTEM:-}" ]; then echo winget; return; fi
    case ${OSTYPE:-} in msys | cygwin) echo winget; return ;; esac
    [ -r /etc/os-release ] || return 1
    local id
    for id in $(. /etc/os-release && echo "${ID:-} ${ID_LIKE:-}"); do
        case $id in
            arch | cachyos)  echo pacman; return ;;
            debian | ubuntu) echo apt; return ;;
        esac
    done
    return 1
}

if [ -z "$manager" ]; then
    manager=$(detect_manager) \
        || die 'cannot tell which package manager this machine uses' \
               'name it with --manager pacman, --manager apt or --manager winget'
fi
# os and distro are what a key in tools.toml can be narrowed to, see there.
case $manager in
    pacman) os=linux   distro=arch ;;
    apt)    os=linux   distro=debian ;;
    winget) os=windows distro=windows ;;
    *)      die "unknown manager $manager" 'pacman, apt or winget' ;;
esac
[ "$list" = 1 ] || [ "$dry" = 1 ] || [ "$setup_only" = 1 ] || command -v "$manager" >/dev/null 2>&1 \
    || die "$manager is not on PATH"

# Where the tools installed by a script, cargo or winget land, which a shell
# started before they were installed does not have on PATH yet -- and a tool
# installed in this run is needed by the next step of it.
PATH=$HOME/.local/bin:$HOME/.cargo/bin:$PATH
if [ "$os" = windows ] && command -v cygpath >/dev/null 2>&1; then
    [ -z "${LOCALAPPDATA:-}" ] || PATH=$PATH:$(cygpath -u "$LOCALAPPDATA")/Microsoft/WinGet/Links
    [ -z "${PROGRAMFILES:-}" ] || PATH=$PATH:$(cygpath -u "$PROGRAMFILES")/nodejs
fi
export PATH

# --- tools.toml ------------------------------------------------------------

# A reader for the part of TOML that tools.toml uses, in awk because a fresh
# machine has awk and nothing that reads TOML: [tables] with bare names, bare
# and dotted keys, "basic" and 'literal' strings, '''multi-line''' literal
# strings, and arrays of strings, over several lines too. Anything else is an
# error with its line, not a guess.
#
# It prints one line per table and per key, its fields separated by \037: the
# table's name alone, then table, key and value. An array's items are joined
# with spaces, and a value's newlines are \036, so every record is one line.
read -r -d '' toml_awk <<'AWK'
function fail(msg) {
    printf "%s:%d: %s\n", FILENAME, FNR, msg > "/dev/stderr"
    err = 1
    exit 1
}
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function emit(key, val) {
    if (table == "") fail("key " key " is outside any [tool] table")
    if ((table SUBSEP key) in seen) fail("key " key " given twice in [" table "]")
    seen[table, key] = 1
    gsub(/\n/, "\036", val)
    printf "%s\037%s\037%s\n", table, key, val
}
# Only a comment may follow a value.
function tail(s) {
    s = trim(s)
    if (s != "" && substr(s, 1, 1) != "#") fail("unexpected " s " after the value")
}
# Spaces, newlines and comments, as they come between an array's items.
function skipws(s) {
    for (;;) {
        sub(/^[ \t\n]+/, "", s)
        if (substr(s, 1, 1) != "#") return s
        sub(/^#[^\n]*/, "", s)
    }
}
# The string at the start of s, in PARSED, and what follows it, in REST.
function str(s,   q, i, c, out) {
    q = substr(s, 1, 1)
    if (q == "'") {
        i = index(substr(s, 2), "'")
        if (!i) fail("unterminated string")
        PARSED = substr(s, 2, i - 1); REST = substr(s, i + 2)
        return
    }
    if (q != "\"") fail("expected a string, at " s)
    out = ""
    for (i = 2; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\") {
            c = substr(s, ++i, 1)
            if (c == "n") c = "\n"
            else if (c == "t") c = "\t"
            else if (c != "\\" && c != "\"") fail("unsupported escape \\" c)
        } else if (c == "\"") {
            PARSED = out; REST = substr(s, i + 1)
            return
        }
        out = out c
    }
    fail("unterminated string")
}
# The array whose items start s, the [ already gone: 1 with its items in
# ARRVAL and what follows in REST, or 0 when the closing ] is on a later line.
function array(s,   out, n, c) {
    out = ""; n = 0
    for (;;) {
        s = skipws(s)
        if (s == "") return 0
        if (substr(s, 1, 1) == "]") { ARRVAL = out; REST = substr(s, 2); return 1 }
        str(s); s = REST
        if (PARSED == "" || PARSED ~ /[ \t\n]/) fail("an array item is a name, without spaces: \"" PARSED "\"")
        out = out (n++ ? " " : "") PARSED
        s = skipws(s)
        if (s == "") return 0
        c = substr(s, 1, 1)
        if (c == ",") s = substr(s, 2)
        else if (c != "]") fail("expected , or ] after \"" PARSED "\"")
    }
}

{ sub(/\r$/, "") }

mlkey != "" {
    i = index($0, "'''")
    if (!i) { mlval = mlval $0 "\n"; next }
    tail(substr($0, i + 3))
    emit(mlkey, mlval substr($0, 1, i - 1))
    mlkey = ""
    next
}

arrkey != "" {
    arrbuf = arrbuf "\n" $0
    if (array(arrbuf)) { tail(REST); emit(arrkey, ARRVAL); arrkey = "" }
    next
}

{
    line = trim($0)
    if (line == "" || substr(line, 1, 1) == "#") next

    if (substr(line, 1, 1) == "[") {
        if (!match(line, /^\[[ \t]*[A-Za-z0-9_-]+[ \t]*\]/)) fail("a table is [name], with a bare name")
        name = trim(substr(line, 2, RLENGTH - 2))
        tail(substr(line, RLENGTH + 1))
        if (name in tables) fail("[" name "] given twice")
        tables[name] = 1; table = name
        printf "%s\037\037\n", table
        next
    }

    if (!match(line, /^[A-Za-z0-9_-]+([ \t]*\.[ \t]*[A-Za-z0-9_-]+)*[ \t]*=[ \t]*/))
        fail("expected key = value")
    key = substr(line, 1, RLENGTH)
    sub(/=.*/, "", key); gsub(/[ \t]/, "", key)
    rest = substr(line, RLENGTH + 1)

    if (substr(rest, 1, 3) == "\"\"\"") fail("a multi-line string is a '''literal''' one here, not \"\"\"")
    if (substr(rest, 1, 3) == "'''") {
        # TOML drops the newline right after the opening quotes.
        rest = substr(rest, 4)
        i = index(rest, "'''")
        if (i) { tail(substr(rest, i + 3)); emit(key, substr(rest, 1, i - 1)); next }
        mlkey = key; mlval = rest == "" ? "" : rest "\n"
        next
    }
    if (substr(rest, 1, 1) == "[") {
        arrbuf = substr(rest, 2)
        if (array(arrbuf)) { tail(REST); emit(key, ARRVAL) } else arrkey = key
        next
    }
    c = substr(rest, 1, 1)
    if (c == "\"" || c == "'") { str(rest); tail(REST); emit(key, PARSED); next }
    fail("a value is a \"string\", a '''script''' or an [array] of strings")
}

END {
    if (err) exit 1
    if (mlkey != "") fail("''' of " mlkey " is never closed")
    if (arrkey != "") fail("[ of " arrkey " is never closed")
}
AWK

parsed=$(awk "$toml_awk" "$conf") || die "cannot read $conf, see above"

# cfg[tool/key] is a key's value; tools are the tables in the file's order,
# and keys[tool] a table's keys in theirs, which is the order of its methods.
declare -A cfg=() keys=()
tools=()
while IFS=$'\037' read -r t k v; do
    [ -n "$t" ] || continue
    if [ -z "$k" ]; then tools+=("$t"); keys[$t]=''; continue; fi
    cfg[$t/$k]=${v//$'\036'/$'\n'}
    keys[$t]+=" $k"
done <<<"$parsed"
[ ${#tools[@]} -gt 0 ] || die "$conf lists no tools"

# The ways a tool can be installed, and the command each runs. The platform's
# own managers need nothing; the others need the tool providing their command.
methods='pacman paru apt winget cargo npm flatpak script'
method_cmd() {
    case $1 in paru | cargo | npm | flatpak) REPLY=$1 ;; *) REPLY='' ;; esac
}
# Where a method can run at all.
method_here() {
    case $1 in
        pacman | paru) [ "$distro" = arch ] ;;
        apt)           [ "$distro" = debian ] ;;
        winget)        [ "$os" = windows ] ;;
        flatpak)       [ "$os" = linux ] ;;
        *)             true ;;
    esac
}

for t in "${tools[@]}"; do
    for k in ${keys[$t]}; do
        base=${k%%.*} q=''
        [ "$k" = "$base" ] || q=${k#*.}
        case $base in
            desc | os) [ -z "$q" ] || die "[$t] $k: $base applies everywhere, it takes no .$q" ;;
            needs | provides | check | setup | setup_check | note | pacman | paru | apt | winget | cargo | npm | flatpak | script)
                case $q in
                    '' | linux | windows | arch | debian) ;;
                    *) die "[$t] $k: .$q is none of .linux, .windows, .arch, .debian" ;;
                esac ;;
            *) die "[$t] unknown key $k" "see the header of $conf" ;;
        esac
    done
    [ -n "${cfg[$t/os]+x}" ] || die "[$t] says nowhere where it belongs" 'os = ["linux", "windows"]'
    for o in ${cfg[$t/os]}; do
        case $o in linux | windows | arch | debian) ;; *) die "[$t] os: $o is none of linux, windows, arch, debian" ;; esac
    done
done

# get TOOL KEY puts the value of KEY that is meant for this machine in REPLY:
# KEY.arch, .debian or .windows first, then KEY.linux or .windows, then KEY.
get() {
    local q
    for q in "$2.$distro" "$2.$os" "$2"; do
        if [ -n "${cfg[$1/$q]+x}" ]; then REPLY=${cfg[$1/$q]}; return 0; fi
    done
    REPLY=''
    return 1
}

declare -A known=()
for t in "${tools[@]}"; do known[$t]=1; done
for t in "${tools[@]}"; do
    for k in ${keys[$t]}; do
        case $k in needs | needs.*) ;; *) continue ;; esac
        for d in ${cfg[$t/$k]}; do
            [ -n "${known[$d]+x}" ] || die "[$t] needs $d, which $conf does not list"
        done
    done
done

# here: the tools that belong on this platform, in the file's order.
here=()
declare -A in_here=()
for t in "${tools[@]}"; do
    case " ${cfg[$t/os]} " in *" $os "* | *" $distro "*) here+=("$t"); in_here[$t]=1 ;; esac
done
[ ${#here[@]} -gt 0 ] || die "$conf lists nothing for $os"

# --- scripts ---------------------------------------------------------------

# A tool's script, check, setup and setup_check run in a bash of their own,
# in the directory of tools.toml, with these in scope. Their own bash, so that
# set -e holds in a script however this one tests what it returns.
helpers=$(cat <<'EOF'
as_root() { if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi; }
# For the setup steps that only give a binary the name the configs call it by.
# Needed when the name is missing, the other one is there, and no link was
# made before -- one in a ~/.local/bin that is not on PATH yet included.
link_needed() {
    ! command -v "$1" >/dev/null 2>&1 && command -v "$2" >/dev/null 2>&1 \
        && [ ! -e "$HOME/.local/bin/$1" ]
}
link_apply() { mkdir -p "$HOME/.local/bin" && ln -s "$(command -v "$2")" "$HOME/.local/bin/$1"; }
EOF
)
helpers+=$'\n'$(declare -p manager os distro)

# A check answers with its status and nothing else.
sh_check() {
    (cd -- "$conf_dir" && bash -c "$helpers"$'\n'"$1") >/dev/null 2>&1 </dev/null
}

# A script is printed before it runs, the way run prints a command.
sh_run() {
    local line
    while IFS= read -r line; do printf '%s  | %s%s\n' "$c_dim" "$line" "$c_off"; done <<<"${1%$'\n'}"
    [ "$dry" = 1 ] && return 0
    (cd -- "$conf_dir" && bash -c "set -euo pipefail"$'\n'"$helpers"$'\n'"$1")
}

# --- what is installed -----------------------------------------------------

# Asked once per manager, and only of the managers some tool here goes
# through: have[manager/package] is set for each package installed.
declare -A have=() loaded=()
winget_list=''
load_have() {
    [ -z "${loaded[$1]+x}" ] || return 0
    loaded[$1]=1
    local p s
    case $1 in
        pacman | paru)
            command -v pacman >/dev/null 2>&1 || return 0
            while read -r p; do have[pacman/$p]=1; done < <(pacman -Qq 2>/dev/null) ;;
        apt)
            command -v dpkg-query >/dev/null 2>&1 || return 0
            while read -r p s; do
                [ "$s" = installed ] && have[apt/$p]=1
            done < <(dpkg-query -W -f='${Package} ${db:Status-Status}\n' 2>/dev/null) ;;
        winget)
            # winget is slow to ask, so it is asked once for everything.
            command -v winget >/dev/null 2>&1 || return 0
            winget_list=$(winget list --accept-source-agreements --disable-interactivity 2>/dev/null) ;;
        cargo)
            command -v cargo >/dev/null 2>&1 || return 0
            while read -r p _; do have[cargo/$p]=1; done < <(cargo install --list 2>/dev/null | grep -v '^[[:space:]]') ;;
        npm)
            command -v npm >/dev/null 2>&1 || return 0
            while read -r p; do
                p=${p//\\//}
                case $p in */node_modules/*) have[npm/${p##*/node_modules/}]=1 ;; esac
            done < <(npm ls -g --depth=0 --parseable 2>/dev/null) ;;
        flatpak)
            command -v flatpak >/dev/null 2>&1 || return 0
            while read -r p; do have[flatpak/$p]=1; done < <(flatpak list --columns=application 2>/dev/null) ;;
    esac
}

pkg_installed() {
    load_have "$1"
    case $1 in
        paru)   [ -n "${have[pacman/$2]+x}" ] ;;
        # Its table pads and may truncate long names, but not the ids looked
        # up here. An id counts only as a whole column, compared without case
        # the way winget does: as a substring, Git.Git would be found in
        # Git.GitLFS.
        winget) awk -v id="$2" 'BEGIN { id = tolower(id) }
                    { for (i = 1; i <= NF; i++) if (tolower($i) == id) { found = 1; exit } }
                    END { exit !found }' <<<"$winget_list" ;;
        *)      [ -n "${have[$1/$2]+x}" ] ;;
    esac
}

# --- what the platform's manager has ---------------------------------------

# avail[package] is set for each package the platform's manager can install.
# Where that cannot be asked -- another platform's manager given with
# --manager, or an apt that has never been updated in a dry run -- every
# package counts as there.
declare -A avail=()
avail_known=0 apt_updated=0

apt_lists() { compgen -G '/var/lib/apt/lists/*_Packages' >/dev/null; }

case $manager in
    pacman)
        if command -v pacman >/dev/null 2>&1; then
            while read -r p; do avail[$p]=1; done < <(pacman -Slq 2>/dev/null)
            [ ${#avail[@]} -eq 0 ] || avail_known=1
        fi ;;
    apt)
        if command -v apt-cache >/dev/null 2>&1; then
            # A fresh container has no package lists at all, and every
            # package would look missing.
            if ! apt_lists && [ "$dry" = 0 ] && [ "$list" = 0 ]; then
                as_root apt-get update && apt_updated=1
            fi
            if apt_lists; then
                apt_pkgs=()
                for t in "${here[@]}"; do get "$t" apt && apt_pkgs+=($REPLY); done
                if [ ${#apt_pkgs[@]} -gt 0 ]; then
                    while read -r p; do avail[$p]=1; done < <(
                        apt-cache policy -- "${apt_pkgs[@]}" 2>/dev/null \
                            | awk '/^[^ ].*:$/ { name = substr($0, 1, length($0) - 1) }
                                   /^ *Candidate:/ && $2 != "(none)" { print name }')
                fi
                avail_known=1
            fi
        fi ;;
esac

available() {
    [ "$avail_known" = 1 ] || return 0
    local p
    for p in $1; do [ -n "${avail[$p]+x}" ] || { REPLY=$p; return 1; }; done
}

# --- how each tool is installed here ---------------------------------------

# via[tool] is the method picked, pkgs[tool] what it installs (the script for
# a script), and missing_pkg[tool] the package the platform's manager lacks
# when that is why another method was picked, or none.
declare -A via=() pkgs=() missing_pkg=()
for t in "${here[@]}"; do
    via[$t]='' pkgs[$t]=''
    seen=' '
    for k in "$manager" ${keys[$t]}; do
        m=${k%%.*}
        case " $methods " in *" $m "*) ;; *) continue ;; esac
        case $seen in *" $m "*) continue ;; esac
        seen+="$m "
        method_here "$m" || continue
        get "$t" "$m" && [ -n "$REPLY" ] || continue
        value=$REPLY
        if [ "$m" = "$manager" ] && ! available "$value"; then
            missing_pkg[$t]=$REPLY; continue
        fi
        via[$t]=$m pkgs[$t]=$value
        break
    done
done

# installed: a tool's check when it has one, else what its method's manager
# says, else whether a command of its name is on PATH.
tool_installed() {
    local p
    if get "$1" check; then sh_check "$REPLY"; return; fi
    case ${via[$1]} in
        '' | script) command -v "$1" >/dev/null 2>&1; return ;;
    esac
    for p in ${pkgs[$1]}; do pkg_installed "${via[$1]}" "$p" || return 1; done
}

# A setup step is to do while its setup_check fails, and always without one.
setup_pending() {
    get "$1" setup || return 1
    get "$1" setup_check || return 0
    ! sh_check "$REPLY"
}

# state[tool]: installed, setup (installed, its setup still to do), missing,
# or manual (missing, and no way to install it here).
declare -A state=()
for t in "${here[@]}"; do
    if tool_installed "$t"; then
        if setup_pending "$t"; then state[$t]=setup; else state[$t]=installed; fi
    elif [ -n "${via[$t]}" ]; then
        state[$t]=missing
    else
        state[$t]=manual
    fi
done

# What a tool needs, in DEPS: its needs, and the tool providing the command
# its method runs -- the one that lists it in provides, or is named after it.
# DEP_ERR says why one cannot be had.
provider_of() {
    local t
    for t in "${here[@]}"; do
        get "$t" provides && case " $REPLY " in *" $1 "*) REPLY=$t; return 0 ;; esac
    done
    [ -n "${in_here[$1]+x}" ] && { REPLY=$1; return 0; }
    return 1
}
deps_of() {
    DEPS=() DEP_ERR=''
    get "$1" needs && DEPS+=($REPLY)
    method_cmd "${via[$1]}"
    local cmd=$REPLY
    [ -n "$cmd" ] || return 0
    if provider_of "$cmd"; then
        case " ${DEPS[*]} " in *" $REPLY "*) ;; *) DEPS+=("$REPLY") ;; esac
    elif ! command -v "$cmd" >/dev/null 2>&1; then
        DEP_ERR="it installs through $cmd, which is not on PATH, and no tool in $conf provides it"
    fi
}

# --- the list --------------------------------------------------------------

row() {
    local t=$1 word='' color=''
    case ${state[$t]} in
        installed) word=installed color=$c_ok ;;
        setup)     word=setup     color=$c_warn ;;
    esac
    printf '%-16s %s%-9s%s %-8s %s' "$t" "$color" "$word" "$c_off" "${via[$t]:--}" "${cfg[$t/desc]:-}"
}

pickable=() manual=()
for t in "${here[@]}"; do
    if [ "${state[$t]}" = manual ]; then manual+=("$t"); else pickable+=("$t"); fi
done

print_manual() {
    [ ${#manual[@]} -gt 0 ] || return 0
    printf '%sno way to install these through %s here, see the README:%s\n' "$c_dim" "$manager" "$c_off"
    local t why
    for t in "${manual[@]}"; do
        why=''
        get "$t" note && why=$REPLY
        [ -n "$why" ] || [ -z "${missing_pkg[$t]:-}" ] || why="this release has no ${missing_pkg[$t]} package"
        printf '%s  %-16s %s%s\n' "$c_dim" "$t" "$why" "$c_off"
    done
}

if [ "$list" = 1 ]; then
    printf '%stools for %s, through %s:%s\n' "$c_bold" "$distro" "$manager" "$c_off"
    for t in "${pickable[@]}"; do
        printf '  '; row "$t"
        deps_of "$t"
        if [ -n "$DEP_ERR" ]; then
            printf '  %s(%s)%s' "$c_bad" "$DEP_ERR" "$c_off"
        elif [ ${#DEPS[@]} -gt 0 ]; then
            printf '  %s(needs %s)%s' "$c_dim" "${DEPS[*]}" "$c_off"
        fi
        printf '\n'
    done
    print_manual
    exit 0
fi

# --- setup only ------------------------------------------------------------

setup_failed=()
setup_of() {
    get "$1" setup || return 0
    local body=$REPLY
    if get "$1" setup_check && sh_check "$REPLY"; then return 0; fi
    printf '%ssetting up %s%s\n' "$c_bold" "$1" "$c_off"
    sh_run "$body" || { setup_failed+=("$1"); return 1; }
}

if [ "$setup_only" = 1 ]; then
    for t in "${wanted[@]}"; do
        [ -n "${in_here[$t]+x}" ] || die "no $t for $os in $conf"
    done
    [ ${#wanted[@]} -gt 0 ] || wanted=("${here[@]}")
    for t in "${wanted[@]}"; do
        case ${state[$t]} in installed | setup) setup_of "$t" ;; esac
    done
    [ ${#setup_failed[@]} -eq 0 ] || die "setup failed: ${setup_failed[*]}"
    printf '%sdone.%s\n' "$c_ok" "$c_off"
    exit 0
fi

# --- the pick --------------------------------------------------------------

picked=()

pick_fzf() {
    local lines t out label
    lines=$(printf '%-16s every tool for %s\n' all "$os"
            for t in "${pickable[@]}"; do row "$t"; printf '\n'; done)
    out=$(fzf --multi --ansi --reverse --height=~60% \
              --prompt="install> " \
              --header="tab picks, enter installs, esc cancels -- through $manager" \
              <<<"$lines") || return 0
    while read -r label _; do
        [ -n "$label" ] || continue
        if [ "$label" = all ]; then picked=("${pickable[@]}"); return 0; fi
        picked+=("$label")
    done <<<"$out"
}

pick_menu() {
    local i answer tok
    printf '%stools for %s, through %s:%s\n' "$c_bold" "$os" "$manager" "$c_off"
    for i in "${!pickable[@]}"; do printf '  %2d) ' $((i + 1)); row "${pickable[i]}"; printf '\n'; done
    printf '   a) all\n'
    print_manual
    read -rp 'install which? (numbers, a for all, enter for none) ' answer || return 0
    for tok in ${answer//,/ }; do
        case $tok in
            a | all) picked=("${pickable[@]}"); return 0 ;;
            *[!0-9]* | '') die "not a number: $tok" ;;
        esac
        [ "$tok" -ge 1 ] && [ "$tok" -le ${#pickable[@]} ] || die "no tool $tok in the list"
        picked+=("${pickable[tok - 1]}")
    done
}

if [ ${#wanted[@]} -gt 0 ]; then
    for t in "${wanted[@]}"; do
        [ -n "${in_here[$t]+x}" ] || die "no $t for $os in $conf" "$self --list shows the ones there are"
        if [ "${state[$t]}" = manual ]; then
            get "$t" note
            die "there is no way to install $t through $manager here" ${REPLY:+"$REPLY"}
        fi
        picked+=("$t")
    done
elif [ "$all" = 1 ]; then
    picked=("${pickable[@]}")
else
    if command -v fzf >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
        print_manual; pick_fzf
    else
        pick_menu
    fi
fi
[ ${#picked[@]} -gt 0 ] || { echo 'nothing picked.'; exit 0; }

# --- the plan --------------------------------------------------------------

# A depth-first walk from each tool picked through what it needs, leaving out
# what is there already. plan is the tools to install or set up, each after
# what it needs; level[tool] is how deep its needs go, so the tools of one
# level can be installed together; tool_deps[tool] what it waits for; and
# reason[tool], for a tool nobody picked, who needs it.
declare -A is_picked=() mark=() level=() tool_deps=() reason=()
for t in "${picked[@]}"; do is_picked[$t]=1; done
plan=() already=() max_level=0

visit() {
    local t=$1 d lv=0
    case ${mark[$t]:-} in
        done)   return 0 ;;
        active) die "the needs of $t go round in a circle, see $conf" ;;
    esac
    mark[$t]=active
    tool_deps[$t]=''
    if [ "${state[$t]}" = missing ]; then
        deps_of "$t"
        [ -z "$DEP_ERR" ] || die "cannot install $t: $DEP_ERR"
        local deps=("${DEPS[@]}")
        for d in "${deps[@]}"; do
            [ -n "${in_here[$d]+x}" ] || die "$t needs $d, which $conf does not list for $os"
            [ "${state[$d]}" = installed ] && continue
            if [ "${state[$d]}" = manual ]; then
                get "$d" note
                die "$t needs $d, and there is no way to install $d through $manager here" \
                    ${REPLY:+"$REPLY"} "install it by hand, then run this again"
            fi
            [ -n "${is_picked[$d]+x}" ] || reason[$d]+="${reason[$d]:+, }$t"
            visit "$d"
            tool_deps[$t]+=" $d"
            [ "${level[$d]}" -lt "$lv" ] || lv=$((level[$d] + 1))
        done
    fi
    mark[$t]=done
    level[$t]=$lv
    [ "$lv" -le "$max_level" ] || max_level=$lv
    plan+=("$t")
}

for t in "${picked[@]}"; do
    if [ "${state[$t]}" = installed ]; then already+=("$t"); else visit "$t"; fi
done

[ ${#already[@]} -eq 0 ] || printf '%salready installed: %s%s\n' "$c_dim" "${already[*]}" "$c_off"
[ ${#plan[@]} -gt 0 ] || { echo 'nothing to do.'; exit 0; }

printf '%sto do, in this order, through %s:%s\n' "$c_bold" "$manager" "$c_off"
for ((lv = 0; lv <= max_level; lv++)); do
    for t in "${plan[@]}"; do
        [ "${level[$t]}" = "$lv" ] || continue
        if [ "${state[$t]}" = setup ]; then what=setup; else what=${via[$t]}; fi
        printf '  %-16s %-8s %s%s%s\n' "$t" "$what" "$c_warn" "${reason[$t]:+needed by ${reason[$t]}}" "$c_off"
    done
done
if [ "$dry" = 0 ] && [ "$yes" = 0 ]; then
    read -rp 'go ahead? [y/N] ' answer || exit 1
    case $answer in y | Y | yes) ;; *) echo 'nothing installed.'; exit 0 ;; esac
fi

# --- install ---------------------------------------------------------------

# failed[tool] says why a tool is not there: its install or setup failed, or
# that of a tool it needs, in which case it is not tried.
declare -A failed=()
confirm=()
[ "$yes" = 0 ] || confirm=(--noconfirm)

fail_all() { local t; for t; do failed[$t]=install; done; }

apt_update() {
    [ "$apt_updated" = 1 ] && return 0
    as_root apt-get update && apt_updated=1
}

npm_global() {
    local prefix
    prefix=$(npm prefix -g 2>/dev/null)
    if [ -n "$prefix" ] && [ -w "$prefix" ]; then run npm install -g "$@"; else as_root npm install -g "$@"; fi
}

# install_with METHOD TOOL...: the managers that take several packages at once
# get every package of the tools given in one go; the rest go tool by tool, so
# one failing does not take the others with it.
install_with() {
    local m=$1 t p
    shift
    local -a ps=() one=()
    for t; do read -ra one <<<"${pkgs[$t]}"; ps+=("${one[@]}"); done
    case $m in
        pacman)  as_root pacman -S --needed "${confirm[@]}" -- "${ps[@]}" || fail_all "$@" ;;
        paru)    run paru -S --needed "${confirm[@]}" -- "${ps[@]}" || fail_all "$@" ;;
        apt)     { apt_update && as_root apt-get install -y -- "${ps[@]}"; } || fail_all "$@" ;;
        npm)     npm_global "${ps[@]}" || fail_all "$@" ;;
        flatpak) as_root flatpak install -y --noninteractive flathub "${ps[@]}" || fail_all "$@" ;;
        winget)
            for t; do
                read -ra one <<<"${pkgs[$t]}"
                for p in "${one[@]}"; do
                    run winget install --exact --id "$p" \
                        --accept-package-agreements --accept-source-agreements \
                        || { failed[$t]=install; break; }
                done
            done ;;
        cargo)
            for t; do
                read -ra one <<<"${pkgs[$t]}"
                run cargo install --locked "${one[@]}" || failed[$t]=install
            done ;;
        script)
            for t; do
                printf '%sinstalling %s%s\n' "$c_bold" "$t" "$c_off"
                sh_run "${pkgs[$t]}" || failed[$t]=install
            done ;;
    esac
}

for ((lv = 0; lv <= max_level; lv++)); do
    declare -A batch=()
    for t in "${plan[@]}"; do
        [ "${level[$t]}" = "$lv" ] || continue
        for d in ${tool_deps[$t]}; do
            [ -z "${failed[$d]+x}" ] || { failed[$t]="needs $d"; continue 2; }
        done
        [ "${state[$t]}" = missing ] && batch[${via[$t]}]+=" $t"
    done
    for m in $methods; do
        [ -n "${batch[$m]:-}" ] || continue
        install_with "$m" ${batch[$m]}
    done
    unset batch
    hash -r
    # After its packages and before what needs it: rust's toolchain comes
    # before the tools cargo builds.
    for t in "${plan[@]}"; do
        [ "${level[$t]}" = "$lv" ] && [ -z "${failed[$t]+x}" ] || continue
        setup_of "$t" || failed[$t]=setup
    done
done

[ "$dry" = 1 ] && exit 0
if [ ${#failed[@]} -gt 0 ]; then
    hints=()
    for t in "${plan[@]}"; do
        case ${failed[$t]:-} in
            '')       ;;
            needs\ *) hints+=("$t: not tried, it ${failed[$t]}") ;;
            *)        hints+=("$t: its ${failed[$t]} failed") ;;
        esac
    done
    die 'not everything was installed' "${hints[@]}"
fi
printf '%sdone.%s\n' "$c_ok" "$c_off"
