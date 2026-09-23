#!/usr/bin/env bash
# One front end for packing and unpacking archives.
#
# Every format comes with its own tool and its own dialect: tar wants -C for a
# target directory, unzip -d, 7z -o glued to the path, unrar a trailing slash.
# Each answers "that file already exists" differently -- tar overwrites, unzip
# asks on the terminal -- and zip, 7z and rar do not replace an existing
# archive at all but add to it. This script reads the format off the file name,
# picks whichever tool for it is installed, and gives them all the same flags
# and the same overwrite rule: nothing existing is touched without --force.
#
# bash rather than POSIX sh: the inputs are lists of paths that may hold
# spaces, which wants arrays, and a quoted glob is expanded here rather than by
# the calling shell, which wants nullglob and globstar.

set -uo pipefail
shopt -s nullglob globstar

self=${0##*/}

# Colors only for a terminal, and never against NO_COLOR or TERM=dumb -- the
# same rule as .local/lib/dotfiles/stow-lib.sh. Diagnostics go to stderr and
# the --dry-run commands to stdout, so each stream gets its own decision.
if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && [ -t 2 ]; then
    e_bold=$'\033[1m' e_dim=$'\033[2m' e_red=$'\033[1;31m' e_green=$'\033[32m'
    e_yellow=$'\033[33m' e_cyan=$'\033[36m' e_off=$'\033[0m'
else
    e_bold='' e_dim='' e_red='' e_green='' e_yellow='' e_cyan='' e_off=''
fi
if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && [ -t 1 ]; then
    o_bold=$'\033[1m' o_dim=$'\033[2m' o_off=$'\033[0m'
else
    o_bold='' o_dim='' o_off=''
fi

# problem prints the reason loudly and one dim hint line per extra argument,
# and counts it; die is a problem that ends the run. Exit 1 is for things that
# went wrong, 2 for a command line that could not be understood.
nproblems=0
problem() {
    printf '%serror:%s %s%s%s\n' "$e_red" "$e_off" "$e_bold" "$1" "$e_off" >&2
    shift
    for hint in "$@"; do printf '%s  %s%s\n' "$e_dim" "$hint" "$e_off" >&2; done
    nproblems=$((nproblems + 1))
}
die() { problem "$@"; exit 1; }
usage_error() { problem "$@" "see: $self --help"; exit 2; }
warn() { printf '%swarning:%s %s\n' "$e_yellow" "$e_off" "$1" >&2; }
note() { printf '%s%s%s\n' "$e_cyan" "$1" "$e_off" >&2; }
ok()   { printf '%s✓%s %s\n' "$e_green" "$e_off" "$1" >&2; }

usage() {
    printf '%susage:%s %s -c [-f FILE]... [-d DIR]... [-o ARCHIVE] [-n] [-F] [FILE...]\n' "$o_bold" "$o_off" "$self"
    printf '       %s -u [-o DIR] [-n] [-F] ARCHIVE...\n\n' "$self"
    cat <<EOF
Packs files into an archive, or unpacks archives, with the format taken from
the file name and the tool from whatever is installed.

commands
  -c, --compress     pack the --file and --dir inputs into --out.
  -u, --uncompress   unpack every ARCHIVE argument into --out.
  -h, -?, --help     this help.

options
  -f, --file FILE    a file to pack. repeatable. quoted, it is a glob expanded
                     here, ** included: -f '*.log' -f 'src/**/*.rs'. plain
                     arguments after -c count as inputs too, so an unquoted
                     glob that the shell expands works the same.
  -d, --dir DIR      a directory to pack, recursively. repeatable, may be a
                     glob.
  -o, --out PATH     with -c the archive to write; its extension picks the
                     format. default: <input>.tar.gz when there is one input.
                     with -u the directory to unpack into, created when
                     missing. default: the current directory.
  -n, --dry-run      print the commands instead of running them.
  -F, --force        with -c replace an existing archive; with -u overwrite
                     existing files. without it both are left alone.

formats
  pack and unpack    .tar  .tar.gz .tgz  .tar.bz2 .tbz2  .tar.xz .txz
                     .tar.zst .tzst  .tar.lz4  .tar.lz  .tar.lzma
                     .zip (and .jar .war .apk .whl .epub ...)  .7z  .rar
                     .gz .bz2 .xz .zst .lz4 .lz .lzma  -- one file each
  unpack only        .iso  .Z

  tools, first installed wins:
    zip   unzip | zip,  then 7zz/7z/7za, then bsdtar
    7z    7zz/7z/7za, then bsdtar
    rar   unrar, 7zz/7z/7za, unar, bsdtar  (packing needs the non-free rar)
    tar   GNU tar, plus gzip/bzip2/xz/zstd/lz4/lzip for the compressed kinds

examples
  $self -u foo.tar.gz bar.zip -o out    unpack both into out/
  $self -c -d src -f '*.md' -o x.7z     a directory and the markdown files
  $self -c -d notes                     notes.tar.gz
  $self -c -f big.log -o big.log.zst    one file, one stream
  $self -un *.rar                       show what would run

exit status: 0 done, 1 something failed, 2 the command line was wrong.
EOF
}

have() { command -v -- "$1" >/dev/null 2>&1; }

# need TOOL... puts the first installed one into TOOL. When none is, MISSING
# holds the whole list so the error can name every way out, not just one.
need() {
    local t
    for t; do have "$t" && { TOOL=$t; return 0; }; done
    MISSING=("$@")
    return 1
}

# The package that ships a tool, for the hint. Debian names, since that is
# what these machines run; elsewhere they are at least a search term.
pkg_of() {
    case $1 in
        7zz) echo 7zip ;;
        7z) echo p7zip-full ;;
        7za) echo p7zip ;;
        bsdtar) echo libarchive-tools ;;
        xz | lzma) echo xz-utils ;;
        *) echo "$1" ;;
    esac
}

missing_hint() {
    local t s=''
    for t in "${MISSING[@]}"; do s+="${s:+, }$t (apt: $(pkg_of "$t"))"; done
    if [ ${#MISSING[@]} -eq 1 ]; then echo "install $s"; else echo "install one of: $s"; fi
}

# fmt_of NAME -> the format key, or status 1 for a name nothing here knows.
# Longest suffix first: foo.tar.gz is a tar, not a gzip of a file named
# foo.tar.
fmt_of() {
    local n=${1##*/}
    case ${n,,} in
        *.tar) echo tar ;;
        *.tar.gz | *.tgz | *.taz) echo tgz ;;
        *.tar.bz2 | *.tbz | *.tbz2 | *.tb2) echo tbz ;;
        *.tar.xz | *.txz) echo txz ;;
        *.tar.zst | *.tar.zstd | *.tzst) echo tzst ;;
        *.tar.lz4) echo tlz4 ;;
        *.tar.lz | *.tlz) echo tlz ;;
        *.tar.lzma) echo tlzma ;;
        *.zip | *.jar | *.war | *.ear | *.apk | *.whl | *.nupkg | *.vsix | *.xpi | *.epub) echo zip ;;
        *.7z) echo 7z ;;
        *.rar) echo rar ;;
        *.iso) echo iso ;;
        *.gz) echo gz ;;
        *.bz2) echo bz2 ;;
        *.xz) echo xz ;;
        *.zst | *.zstd) echo zst ;;
        *.lz4) echo lz4 ;;
        *.lz) echo lz ;;
        *.lzma) echo lzma ;;
        *.z) echo Z ;;
        *) return 1 ;;
    esac
}

is_stream() { case $1 in gz | bz2 | xz | zst | lz4 | lz | lzma | Z) return 0 ;; esac; return 1; }
is_tar() { case $1 in tar | tgz | tbz | txz | tzst | tlz4 | tlz | tlzma) return 0 ;; esac; return 1; }

# tar's flag for a compressed tar, and the program tar will run for it, which
# has to be installed as well: GNU tar does not compress anything itself.
tar_codec() {
    case $1 in
        tar) TARZ=() ZBIN='' ;;
        tgz) TARZ=(-z) ZBIN=gzip ;;
        tbz) TARZ=(-j) ZBIN=bzip2 ;;
        txz) TARZ=(-J) ZBIN=xz ;;
        tzst) TARZ=(--zstd) ZBIN=zstd ;;
        tlz4) TARZ=(-I lz4) ZBIN=lz4 ;;
        tlz) TARZ=(--lzip) ZBIN=lzip ;;
        tlzma) TARZ=(--lzma) ZBIN=lzma ;;
    esac
}

# The single-file compressors. All of them take -c for stdout and -d to
# decompress, which is what lets one table serve both directions.
stream_codec() {
    case $1 in
        gz | Z) ZCMD=(gzip) ;;
        bz2) ZCMD=(bzip2) ;;
        xz) ZCMD=(xz) ;;
        zst) ZCMD=(zstd -q) ;;
        lz4) ZCMD=(lz4 -q) ;;
        lz) ZCMD=(lzip) ;;
        lzma) ZCMD=(xz --format=lzma) ;;
    esac
}

# A path that begins with a dash would be read as an option by every tool
# below, and not all of them honour `--`; ./ in front makes it a path to all.
safe() { case $1 in -*) REPLY=./$1 ;; *) REPLY=$1 ;; esac; }

# expand PATTERN -> MATCHES. A path that exists is taken as it is, so names
# holding [ or * still work; anything else is a glob.
expand() {
    MATCHES=()
    if [ -e "$1" ] || [ -L "$1" ]; then MATCHES=("$1"); return; fi
    local IFS=''
    # shellcheck disable=SC2206 # the glob is the point; IFS='' stops splitting
    MATCHES=($1)
    # nullglob only drops patterns: a plain name that matched nothing is
    # still here, as itself.
    if [ ${#MATCHES[@]} -eq 1 ] && [ "${MATCHES[0]}" = "$1" ] && ! [ -e "$1" ]; then
        MATCHES=()
    fi
}
is_glob() { case $1 in *[*?[]*) return 0 ;; esac; return 1; }

# --- planning ----------------------------------------------------------------
# plan_* fill CMD (the argv to run) and REDIR (a file its stdout goes to, for
# the single-file formats), or fail with MISSING set when no tool is there.

plan_extract() {
    local a=$1 d=$2 f=$3
    CMD=() REDIR=''
    if is_tar "$f"; then
        tar_codec "$f"
        need tar || return 1
        [ -z "$ZBIN" ] || need "$ZBIN" || return 1
        CMD=(tar -x "${TARZ[@]}" -f "$a" -C "$d")
        if ((force)); then CMD+=(--overwrite); else CMD+=(--skip-old-files); fi
        return 0
    fi
    if is_stream "$f"; then
        stream_codec "$f"
        need "${ZCMD[0]}" || return 1
        local base=${a##*/} stem
        stem=${base%.*}
        [ -n "$stem" ] && [ "$stem" != "$base" ] || stem=$base.out
        CMD=("${ZCMD[@]}" -dc "$a") REDIR=$d/$stem
        return 0
    fi
    case $f in
        zip) need unzip 7zz 7z 7za bsdtar || return 1 ;;
        rar) need unrar 7zz 7z 7za unar bsdtar || return 1 ;;
        7z | iso) need 7zz 7z 7za bsdtar || return 1 ;;
    esac
    case $TOOL in
        unzip)
            CMD=(unzip -q)
            if ((force)); then CMD+=(-o); else CMD+=(-n); fi
            CMD+=("$a" -d "$d") ;;
        unrar)
            CMD=(unrar x -idq)
            if ((force)); then CMD+=(-o+); else CMD+=(-o-); fi
            CMD+=("$a" "$d/") ;;
        unar)
            # -D: no extra directory of its own around the contents
            CMD=(unar -q -D -o "$d")
            if ((force)); then CMD+=(-f); else CMD+=(-s); fi
            CMD+=("$a") ;;
        bsdtar)
            CMD=(bsdtar -x -f "$a" -C "$d")
            ((force)) || CMD+=(-k) ;;
        7z*)
            CMD=("$TOOL" x -y -bso0 -bsp0 "-o$d")
            if ((force)); then CMD+=(-aoa); else CMD+=(-aos); fi
            CMD+=("$a") ;;
    esac
}

plan_compress() {
    local o=$1 f=$2
    shift 2
    CMD=() REDIR=''
    if is_tar "$f"; then
        tar_codec "$f"
        need tar || return 1
        [ -z "$ZBIN" ] || need "$ZBIN" || return 1
        CMD=(tar -c "${TARZ[@]}" -f "$o" "$@")
        return 0
    fi
    if is_stream "$f"; then
        stream_codec "$f"
        need "${ZCMD[0]}" || return 1
        CMD=("${ZCMD[@]}" -c "$1") REDIR=$o
        return 0
    fi
    case $f in
        zip) need zip 7zz 7z 7za bsdtar || return 1 ;;
        7z) need 7zz 7z 7za bsdtar || return 1 ;;
        rar) need rar || return 1 ;;
    esac
    case $TOOL in
        zip) CMD=(zip -r -q "$o" "$@") ;;
        rar) CMD=(rar a -r -idq "$o" "$@") ;;
        # -spd: the names are paths, not 7z's own wildcards
        7z*) CMD=("$TOOL" a "-t$f" -spd -bso0 -bsp0 "$o" "$@") ;;
        bsdtar)
            if [ "$f" = zip ]; then CMD=(bsdtar --format zip -c -f "$o" "$@")
            else CMD=(bsdtar --format 7zip -c -f "$o" "$@"); fi ;;
    esac
}

# --- running -----------------------------------------------------------------

show() {
    local s
    s=$(printf '%q ' "${CMD[@]}")
    s=${s% }
    [ -z "$REDIR" ] || s+=" > $(printf '%q' "$REDIR")"
    printf '%s$%s %s\n' "$o_dim" "$o_off" "$s"
}

# run CMD, or with --dry-run only show it. With an argument, stdout goes into
# that file rather than REDIR: the real run writes to a scratch name and moves
# it into place, the dry run shows where it would end up.
execute() {
    if ((dry)); then show; return 0; fi
    if [ $# -gt 0 ]; then "${CMD[@]}" >"$1"; else "${CMD[@]}"; fi
}

mkdirs() {
    [ -d "$1" ] && return 0
    CMD=(mkdir -p -- "$1") REDIR=''
    execute || die "cannot create directory: $1"
}

# The archive or file being written, under a scratch name next to its target
# until it is complete -- so a failure or ctrl-c never leaves half of one
# behind, and --force replaces the old one only once the new one is whole.
partial=''
trap '[ -z "$partial" ] || rm -f -- "$partial"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

human_size() {
    numfmt --to=iec --suffix=B "$(stat -c %s -- "$1" 2>/dev/null)" 2>/dev/null || echo '?'
}

# --- compress ----------------------------------------------------------------

compress() {
    local p m inputs=()

    for p in "${files[@]}"; do
        expand "$p"
        [ ${#MATCHES[@]} -gt 0 ] || { problem "no such file: $p"; continue; }
        local kept=0
        for m in "${MATCHES[@]}"; do
            if [ -d "$m" ]; then
                if is_glob "$p"; then
                    warn "skipping directory $m matched by --file '$p'"
                else
                    problem "is a directory: $p" "pass directories with --dir"
                fi
                continue
            fi
            inputs+=("$m") kept=1
        done
        [ "$kept" = 1 ] || ! is_glob "$p" || problem "no files match: $p"
    done
    for p in "${dirs[@]}"; do
        expand "$p"
        [ ${#MATCHES[@]} -gt 0 ] || { problem "no such directory: $p"; continue; }
        for m in "${MATCHES[@]}"; do
            if [ -d "$m" ]; then inputs+=("$m")
            else problem "not a directory: $m" "pass files with --file"; fi
        done
    done
    # plain arguments: a shell-expanded glob after -f lands here, and it may
    # hold both files and directories
    for p in "${args[@]}"; do
        expand "$p"
        [ ${#MATCHES[@]} -gt 0 ] || { problem "no such file or directory: $p"; continue; }
        inputs+=("${MATCHES[@]}")
    done
    ((nproblems == 0)) || exit 1
    [ ${#inputs[@]} -gt 0 ] || usage_error 'nothing to compress' 'name inputs with --file, --dir or as arguments'

    for p in "${inputs[@]}"; do
        [ -r "$p" ] || problem "not readable: $p"
    done
    ((nproblems == 0)) || exit 1

    if [ -z "$out" ]; then
        [ ${#inputs[@]} -eq 1 ] \
            || usage_error "--out is needed with ${#inputs[@]} inputs" 'e.g. -o bundle.tar.gz'
        p=${inputs[0]%/}
        out=${p##*/}.tar.gz
        [ "$out" != .tar.gz ] && [ "$out" != ..tar.gz ] || out=archive.tar.gz
    fi
    case $out in */) usage_error "--out is a directory: $out" 'name the archive file, e.g. -o dir/name.zip' ;; esac
    [ ! -d "$out" ] || usage_error "--out is a directory: $out" 'name the archive file, e.g. -o dir/name.zip'

    local fmt
    fmt=$(fmt_of "$out") || usage_error "unknown archive type: $out" 'end --out in .tar.gz, .zip, .7z, ... (see the list in --help)'
    case $fmt in
        iso | Z) usage_error "${out##*.} archives can only be unpacked here" 'pick another format, e.g. .tar.gz or .zip' ;;
    esac
    if is_stream "$fmt"; then
        [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ] \
            || usage_error ".${out##*.} holds exactly one file, not ${#inputs[@]} input(s) or a directory" \
                "use .tar.${out##*.} to pack several files or a directory"
    fi

    if [ -e "$out" ] || [ -L "$out" ]; then
        ((force)) || die "already exists: $out" 'pass --force to replace it'
        [ -f "$out" ] || die "exists and is not a regular file: $out"
    fi

    # An archive written inside a directory it packs would try to swallow
    # itself: tar notices, 7z and zip do not reliably.
    local outdir odir idir
    outdir=$(dirname -- "$out")
    odir=$(realpath -m -- "$outdir")
    for p in "${inputs[@]}"; do
        [ -d "$p" ] || continue
        idir=$(realpath -m -- "$p")
        case $odir/ in "$idir"/*)
            die "$out would be written inside $p, which it packs" 'put it somewhere else, e.g. -o ../'"${out##*/}" ;;
        esac
    done

    local sin=()
    for p in "${inputs[@]}"; do safe "$p"; sin+=("$REPLY"); done
    safe "$out"
    local sout=$REPLY tmp="$outdir/.part$$.${out##*/}"
    safe "$tmp"
    local stmp=$REPLY

    # plan against the final name for show, the scratch one for real: the
    # tools see its extension either way, which is what rar and 7z go by
    plan_compress "$sout" "$fmt" "${sin[@]}" || die "no tool to write .${out##*.}" "$(missing_hint)"

    mkdirs "$outdir"
    if ((dry)); then
        execute
        return 0
    fi

    plan_compress "$stmp" "$fmt" "${sin[@]}"
    partial=$tmp
    if [ -n "$REDIR" ]; then execute "$tmp"; else execute; fi || die "failed to create $out" "${CMD[0]} exited non-zero; its own message is above"
    mv -f -- "$tmp" "$out" || die "cannot move the new archive into place: $out"
    partial=''
    ok "created $out ($(human_size "$out"), ${#inputs[@]} input(s), via ${CMD[0]})"
}

# --- uncompress --------------------------------------------------------------

uncompress() {
    local p m a fmt archives=()

    [ ${#files[@]} -eq 0 ] && [ ${#dirs[@]} -eq 0 ] \
        || usage_error '--file and --dir are for --compress' 'with --uncompress name the archives as arguments'

    for p in "${args[@]}"; do
        expand "$p"
        [ ${#MATCHES[@]} -gt 0 ] || { problem "no such archive: $p"; continue; }
        archives+=("${MATCHES[@]}")
    done
    [ ${#archives[@]} -gt 0 ] || ((nproblems)) || usage_error 'nothing to uncompress' 'name the archives as arguments'

    local dest=${out:-.}
    [ ! -e "$dest" ] || [ -d "$dest" ] || usage_error "--out is not a directory: $dest"
    safe "$dest"
    local sdest=$REPLY

    # Check every archive before unpacking any, so a missing tool or a typo in
    # the fifth name does not leave the first four half done.
    for a in "${archives[@]}"; do
        if [ -d "$a" ]; then problem "is a directory: $a"; continue; fi
        [ -f "$a" ] || { problem "not a regular file: $a"; continue; }
        [ -r "$a" ] || { problem "not readable: $a"; continue; }
        fmt=$(fmt_of "$a") || { problem "unknown archive type: $a" 'see the list of formats in --help'; continue; }
        safe "$a"
        plan_extract "$REPLY" "$sdest" "$fmt" || problem "no tool to unpack $a" "$(missing_hint)"
    done
    ((nproblems == 0)) || exit 1

    mkdirs "$dest"

    local failed=0 done=0 skipped=0 target
    for a in "${archives[@]}"; do
        fmt=$(fmt_of "$a")
        safe "$a"
        plan_extract "$REPLY" "$sdest" "$fmt"
        if ((dry)); then execute; continue; fi

        if [ -n "$REDIR" ]; then
            target=$dest/${REDIR##*/}
            if [ -e "$target" ] && ! ((force)); then
                warn "skipping $a: $target exists (--force replaces it)"
                skipped=$((skipped + 1))
                continue
            fi
            partial=$dest/.part$$.${REDIR##*/}
            if execute "$partial" && mv -f -- "$partial" "$target"; then
                partial=''
                ok "$a → $target"
                done=$((done + 1))
            else
                rm -f -- "$partial"
                partial=''
                problem "failed to unpack $a" "${CMD[0]} exited non-zero; its own message is above"
                failed=$((failed + 1))
            fi
            continue
        fi

        if execute; then
            ok "$a → ${dest%/}/"
            done=$((done + 1))
        else
            problem "failed to unpack $a" "${CMD[0]} exited non-zero; its own message is above"
            failed=$((failed + 1))
        fi
    done

    ((dry)) && return 0
    if [ ${#archives[@]} -gt 1 ] || ((failed)); then
        note "$done unpacked, $skipped skipped, $failed failed"
    fi
    ((failed == 0)) || exit 1
}

# --- command line ------------------------------------------------------------

main() {
    mode='' dry=0 force=0 out='' out_set=0
    files=() dirs=() args=()

    [ $# -gt 0 ] || { usage >&2; exit 2; }

    # Split bundled short options, -cnF into -c -n -F. A value-taking letter
    # ends the bundle and takes the rest as its value: -ofoo.zip. The word
    # after a value-taking option is its value, whatever it looks like.
    local argv=() s c prev=''
    while [ $# -gt 0 ]; do
        case $prev in
            -f | -d | -o | --file | --dir | --out) argv+=("$1") prev=''; shift; continue ;;
        esac
        prev=$1
        case $1 in
            --) argv+=("$@"); break ;;
            --* | - | '-?') argv+=("$1") ;;
            -??*)
                s=${1#-}
                while [ -n "$s" ]; do
                    c=${s:0:1} s=${s:1}
                    argv+=("-$c") prev=-$c
                    case $c in f | d | o) [ -z "$s" ] || argv+=("$s") prev=''; break ;; esac
                done ;;
            *) argv+=("$1") ;;
        esac
        shift
    done
    set -- "${argv[@]}"

    while [ $# -gt 0 ]; do
        case $1 in
            -c | --compress) set_mode compress ;;
            -u | --uncompress | -x | --extract) set_mode uncompress ;;
            -h | --help | '-?') usage; exit 0 ;;
            -n | --dry-run) dry=1 ;;
            -F | --force) force=1 ;;
            -f | --file) need_value "$@"; files+=("$2"); shift ;;
            -d | --dir) need_value "$@"; dirs+=("$2"); shift ;;
            -o | --out) need_value "$@"; set_out "$2"; shift ;;
            --file=*) files+=("${1#*=}") ;;
            --dir=*) dirs+=("${1#*=}") ;;
            --out=*) set_out "${1#*=}" ;;
            --) shift; args+=("$@"); break ;;
            -*) usage_error "unknown option: $1" ;;
            *) args+=("$1") ;;
        esac
        shift
    done

    case $mode in
        compress) compress ;;
        uncompress) uncompress ;;
        *) usage_error 'no command given' "-c to pack, -u to unpack" ;;
    esac
}

set_mode() {
    [ -z "$mode" ] || [ "$mode" = "$1" ] || usage_error '--compress and --uncompress exclude each other'
    mode=$1
}

set_out() {
    ((out_set == 0)) || usage_error "--out given twice: $out and $1"
    [ -n "$1" ] || usage_error '--out is empty'
    out=$1 out_set=1
}

# A value that looks like an option is taken as one unless a file by that name
# exists: `-o -n` is a forgotten value far more often than an archive called
# -n. ./-n always gets through.
need_value() {
    [ $# -ge 2 ] || usage_error "$1 needs a value"
    case $2 in -?*)
        [ -e "$2" ] || usage_error "$1 needs a value, got the option $2" "a name that starts with - goes as ./$2" ;;
    esac
}

main "$@"
