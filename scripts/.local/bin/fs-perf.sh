#!/bin/sh
# fs-perf.sh - filesystem access performance probe, run from inside WSL.
#
# Measures the two WSL-side halves of the WSL/Windows filesystem matrix:
#
#   ext4   WSL -> ext4   (native Linux filesystem inside the WSL VM)
#   ntfs   WSL -> NTFS   (Windows drive through drvfs, e.g. /mnt/c)
#
# The Windows-side halves (Windows -> NTFS native and Windows -> ext4 over
# \\wsl.localhost) are measured by the companion script fs-perf.ps1.
#
# Both scripts build the *same* synthetic code repository - identical
# directory layout, file names, file sizes and byte content - and run the
# same phases, so all four combinations can be compared.
#
# Dependencies: only what a default Ubuntu install ships. POSIX sh builtins
# plus coreutils (date, stat, df, mkdir, mv, rm, cat, sync), findutils, grep,
# wc, awk. No bashisms, no third-party benchmarking tools.

set -u

PROG=${0##*/}
COUNT=2000
TARGETS=""
EXT4_DIR=""
WIN_DIR=""
KEEP=0
DROP=0
CSV=""
TOTAL_BYTES=0
RUN_TARGETS=""

usage() {
    cat <<'USAGE'
Usage: fs-perf.sh [options]

Options:
  -n, --count N        number of files in the synthetic repo (default 2000)
  -t, --targets LIST   comma separated subset of: ext4,ntfs (default both)
      --ext4-dir DIR   base dir on the native Linux fs (default $HOME/.cache/fs-perf)
      --win-dir DIR    base dir on a Windows drive (default: auto-detected under /mnt/*)
      --drop-caches    drop the Linux page cache before each read phase (needs root)
      --keep           keep the test trees for inspection (skips the delete phase)
      --csv FILE       also write raw results as CSV
  -h, --help           this text

Phases (all timed separately):
  mkdir   create the directory skeleton
  write   create N files with code-like content
  sync    sync(1) - flush dirty pages to the backing store
  stat    full tree walk with an lstat per entry (find -type f -size +0c)
  read    read every file end to end (cat)
  grep    recursive content scan for a fixed token (grep -rlF)
  modify  append a line to every 10th file
  rename  rename every 10th file
  delete  rm -rf the whole tree

Note: on /mnt/* the numbers include the Windows side of the 9p/drvfs
transport plus whatever Defender real-time scanning costs. That is the
point - it is what a build actually pays.
USAGE
}

die() { printf '%s: %s\n' "$PROG" "$*" >&2; exit 2; }
need_arg() { [ "$2" -ge 2 ] || die "option $1 requires an argument"; }

while [ $# -gt 0 ]; do
    case $1 in
        -n|--count)     need_arg "$1" $#; COUNT=$2; shift 2 ;;
        -t|--targets)   need_arg "$1" $#; TARGETS=$(echo "$2" | tr ',' ' '); shift 2 ;;
        --ext4-dir)     need_arg "$1" $#; EXT4_DIR=$2; shift 2 ;;
        --win-dir|--ntfs-dir) need_arg "$1" $#; WIN_DIR=$2; shift 2 ;;
        --drop-caches)  DROP=1; shift ;;
        --keep)         KEEP=1; shift ;;
        --csv)          need_arg "$1" $#; CSV=$2; shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *)              usage >&2; die "unknown option: $1" ;;
    esac
done

case $COUNT in ''|*[!0-9]*) die "--count must be a positive integer" ;; esac
[ "$COUNT" -ge 10 ] || die "--count must be >= 10"
[ -n "$TARGETS" ] || TARGETS="ext4 ntfs"

# ---------------------------------------------------------------- timing ----

NS_OK=1
case $(date +%N 2>/dev/null) in
    ''|*[!0-9]*) NS_OK=0 ;;
esac

if [ "$NS_OK" = 1 ]; then
    now_ms() { _n=$(date +%s%N); echo $((_n / 1000000)); }
else
    now_ms() { _n=$(date +%s); echo $((_n * 1000)); }
fi

fmt_ms() { printf '%d.%03d' $(($1 / 1000)) $(($1 % 1000)); }

per_sec() {  # ms ops
    [ "$2" -le 0 ] && { printf '-'; return; }
    _ms=$1
    [ "$_ms" -lt 1 ] && _ms=1
    printf '%d/s' $(($2 * 1000 / _ms))
}

mib_per_sec() {  # ms bytes
    [ "$2" -le 0 ] && { printf ''; return; }
    _ms=$1
    [ "$_ms" -lt 1 ] && _ms=1
    _bps=$(($2 * 1000 / _ms))
    printf '%d.%02d MiB/s' $((_bps / 1048576)) $((_bps % 1048576 * 100 / 1048576))
}

ratio() {  # base other
    _a=$1
    _b=$2
    [ "$_a" -lt 1 ] && _a=1
    [ "$_b" -lt 0 ] && { printf 'n/a'; return; }
    _x=$((_b * 100 / _a))
    printf '%d.%02dx' $((_x / 100)) $((_x % 100))
}

# ------------------------------------------------------------- templates ----
# One "unit" of code-like content per file kind. Repeated 1/2/4/6/10 times so
# file sizes spread the way they do in a real repository. Kept free of single
# quotes so the exact same bytes can live in a PowerShell here-string.

SLASH_T='
// TODO(perf) revisit hot path before release'
HASH_T='
# TODO(perf) revisit hot path before release'
NL2='

'

EXT_0=ts;   NAME_0=service;  P_0='// module ';   T_0=$SLASH_T; M_0=$NL2; Q_0=''
EXT_1=tsx;  NAME_1=Panel;    P_1='// module ';   T_1=$SLASH_T; M_1=$NL2; Q_1=''
EXT_2=js;   NAME_2=util;     P_2='// module ';   T_2=$SLASH_T; M_2=$NL2; Q_2=''
EXT_3=py;   NAME_3=models;   P_3='# module ';    T_3=$HASH_T;  M_3=$NL2; Q_3=''
EXT_4=go;   NAME_4=store;    P_4='// module ';   T_4=$SLASH_T; M_4=$NL2; Q_4=''
EXT_5=json; NAME_5=lockfile; P_5='{"id": '
EXT_6=md;   NAME_6=notes;    P_6='<!-- module '
EXT_7=css;  NAME_7=styles;   P_7='/* module '
EXT_8=yaml; NAME_8=deploy;   P_8='# module ';    T_8=$HASH_T;  M_8=$NL2; Q_8=''
EXT_9=sh;   NAME_9=build;    P_9='# module ';    T_9=$HASH_T;  M_9=$NL2; Q_9=''

T_5=', "todo": "TODO(perf) revisit hot path before release"'
M_5=', "entries": [
'
Q_5='  {"name": "dep-omega", "version": "0.0.1", "dev": true}
]}
'

T_6=' TODO(perf) revisit hot path before release'
M_6=' -->

'
Q_6=''

T_7=' TODO(perf) revisit hot path before release'
M_7=' */

'
Q_7=''

U_0='export interface RequestContext {
  traceId: string;
  userId: string | null;
  startedAt: number;
}

export async function handleRequest(ctx: RequestContext, payload: Record<string, unknown>) {
  const started = Date.now();
  try {
    const result = await dispatch(ctx.traceId, payload);
    return { ok: true, result, durationMs: Date.now() - started };
  } catch (err) {
    logger.error("dispatch failed", { traceId: ctx.traceId, err });
    return { ok: false, error: String(err) };
  }
}

'

U_1='import { useEffect, useState } from "react";

export function StatusBadge({ jobId }: { jobId: string }) {
  const [state, setState] = useState<"idle" | "running" | "done">("idle");
  useEffect(() => {
    const timer = setInterval(() => void poll(jobId).then(setState), 2000);
    return () => clearInterval(timer);
  }, [jobId]);
  return <span className={"badge badge--" + state}>{state}</span>;
}

'

U_2='const { createHash } = require("node:crypto");

function cacheKey(parts) {
  const h = createHash("sha256");
  for (const p of parts) h.update(String(p)).update("|");
  return h.digest("hex").slice(0, 32);
}

async function retry(fn, attempts = 3, delayMs = 50) {
  let lastErr;
  for (let i = 0; i < attempts; i += 1) {
    try {
      return await fn();
    } catch (e) {
      lastErr = e;
      await sleep(delayMs * (i + 1));
    }
  }
  throw lastErr;
}

module.exports = { cacheKey, retry };

'

U_3='from dataclasses import dataclass


@dataclass(frozen=True)
class Record:
    key: str
    value: bytes
    version: int = 0


def merge(left, right):
    """Last writer wins, per key, by version."""
    out = dict(left)
    for key, rec in right.items():
        cur = out.get(key)
        if cur is None or cur.version < rec.version:
            out[key] = rec
    return out

'

U_4='package store

import (
    "context"
    "errors"
    "time"
)

var ErrNotFound = errors.New("store: not found")

func (s *Store) Get(ctx context.Context, key string) ([]byte, error) {
    ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
    defer cancel()
    v, ok := s.cache.Load(key)
    if !ok {
        return nil, ErrNotFound
    }
    return v.([]byte), nil
}

'

U_5='  {"name": "dep-a", "version": "1.4.2", "resolved": "https://registry.example.com/dep-a/-/dep-a-1.4.2.tgz", "integrity": "sha512-AAAABBBBCCCCDDDDEEEEFFFF0000111122223333444455556666777788889999", "dev": false},
  {"name": "dep-b", "version": "0.9.17", "resolved": "https://registry.example.com/dep-b/-/dep-b-0.9.17.tgz", "integrity": "sha512-9999888877776666555544443333222211110000FFFFEEEEDDDDCCCCBBBBAAAA", "dev": true},
'

U_6='## Overview

This module owns request fan-out and retry accounting. It deliberately
avoids framework imports so it can be exercised from plain unit tests.

- `handleRequest` normalises the incoming payload
- `retry` applies linear backoff and re-raises the last error
- every failure is logged with the trace id, never swallowed

    make test PKG=./src/...

'

U_7='.panel {
  display: grid;
  grid-template-columns: minmax(12rem, 18rem) 1fr;
  gap: var(--space-3, 12px);
  border: 1px solid var(--border-muted, #d0d7de);
  border-radius: 6px;
}

.panel > header {
  font: 600 13px/1.4 ui-sans-serif, system-ui, sans-serif;
  color: var(--fg-default, #1f2328);
}

'

U_8='apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: api
          image: registry.example.com/api:1.4.2
          resources:
            requests:
              cpu: 250m
              memory: 256Mi

'

U_9='set -eu

log() {
  printf "%s %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

main() {
  [ $# -ge 1 ] || { log "usage: build.sh TARGET"; return 2; }
  target=$1
  log "building ${target}"
  make -C "src/${target}" all
}

'

# Precompute the repeated bodies once, so the write phase measures the
# filesystem and not string concatenation.
build_bodies() {
    s=0
    for r in 1 2 4 6 10; do
        k=0
        while [ "$k" -lt 10 ]; do
            eval "u=\$U_$k"
            b=$u
            j=1
            while [ "$j" -lt "$r" ]; do
                b="$b$u"
                j=$((j + 1))
            done
            eval "B_${k}_${s}=\$b"
            k=$((k + 1))
        done
        s=$((s + 1))
    done
}

# ---------------------------------------------------------------- phases ----

DIR_COUNT=$(((COUNT + 9) / 10))
MOD_COUNT=$(((COUNT + 9) / 10))

phase_mkdir() {
    root=$1
    set --
    i=0
    n=0
    while [ "$i" -lt "$COUNT" ]; do
        pkg=$((i / 100))
        part=$(((i % 100) / 10))
        if [ "$pkg" -lt 10 ]; then pp="0$pkg"; else pp="$pkg"; fi
        set -- "$@" "$root/src/pkg$pp/part$part"
        n=$((n + 1))
        if [ "$n" -ge 400 ]; then
            mkdir -p "$@" || return 1
            set --
            n=0
        fi
        i=$((i + 10))
    done
    if [ "$n" -gt 0 ]; then mkdir -p "$@" || return 1; fi
    return 0
}

phase_write() {
    root=$1
    bytes=0
    i=0
    while [ "$i" -lt "$COUNT" ]; do
        k=$((i % 10))
        s=$((i % 5))
        pkg=$((i / 100))
        part=$(((i % 100) / 10))
        if [ "$pkg" -lt 10 ]; then pp="0$pkg"; else pp="$pkg"; fi
        eval "ext=\$EXT_$k; nm=\$NAME_$k; p=\$P_$k; m=\$M_$k; q=\$Q_$k; b=\$B_${k}_${s}"
        if [ $((i % 7)) -eq 0 ]; then eval "t=\$T_$k"; else t=''; fi
        printf '%s%s%s%s%s%s' "$p" "$i" "$t" "$m" "$b" "$q" \
            > "$root/src/pkg$pp/part$part/${nm}_$i.$ext" || return 1
        bytes=$((bytes + ${#p} + ${#i} + ${#t} + ${#m} + ${#b} + ${#q}))
        i=$((i + 1))
    done
    TOTAL_BYTES=$bytes
    return 0
}

phase_sync() { sync; }
phase_stat() { find "$1" -type f -size +0c | wc -l > /dev/null; }
phase_read() { find "$1" -type f -exec cat {} + > /dev/null; }
phase_grep() { grep -rlF 'TODO(perf)' "$1" > /dev/null 2>&1 || true; }

phase_modify() {
    root=$1
    i=0
    while [ "$i" -lt "$COUNT" ]; do
        k=$((i % 10))
        pkg=$((i / 100))
        part=$(((i % 100) / 10))
        if [ "$pkg" -lt 10 ]; then pp="0$pkg"; else pp="$pkg"; fi
        eval "ext=\$EXT_$k; nm=\$NAME_$k"
        printf '%s\n' '// touched by fs-perf' \
            >> "$root/src/pkg$pp/part$part/${nm}_$i.$ext" || return 1
        i=$((i + 10))
    done
    return 0
}

phase_rename() {
    root=$1
    i=0
    while [ "$i" -lt "$COUNT" ]; do
        k=$((i % 10))
        pkg=$((i / 100))
        part=$(((i % 100) / 10))
        if [ "$pkg" -lt 10 ]; then pp="0$pkg"; else pp="$pkg"; fi
        eval "ext=\$EXT_$k; nm=\$NAME_$k"
        f="$root/src/pkg$pp/part$part/${nm}_$i.$ext"
        mv "$f" "$f.bak" || return 1
        i=$((i + 10))
    done
    return 0
}

phase_delete() { rm -rf "$1"; }

ops_for() {
    case $1 in
        mkdir)         echo "$DIR_COUNT" ;;
        modify|rename) echo "$MOD_COUNT" ;;
        sync|delete)   echo 0 ;;
        *)             echo "$COUNT" ;;
    esac
}

maybe_drop() {
    [ "$DROP" = 1 ] || return 0
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    return 0
}

PHASES='mkdir write sync stat read grep modify rename delete'
# --keep exists to leave the corpus behind for inspection, so the delete
# phase would defeat it; drop that phase instead of the request.
[ "$KEEP" = 1 ] && PHASES='mkdir write sync stat read grep modify rename'

mount_info() {
    d=$1
    mp=$(df -P "$d" 2>/dev/null | awk 'NR==2 {print $6}')
    [ -n "$mp" ] || return 0
    line=$(awk -v m="$mp" '$2 == m {print $1" type "$3" ("$4")"; exit}' /proc/mounts)
    ft=$(stat -f -c '%T' "$d" 2>/dev/null)
    printf '   mount:  %s\n' "${line:-$mp}"
    [ -n "$ft" ] && printf '   fstype: %s\n' "$ft"
    return 0
}

run_target() {
    tgt=$1
    root=$2
    printf '\n== %s ==\n   path:   %s\n' "$tgt" "$root"
    mount_info "$(dirname "$root")"
    TOTAL_BYTES=0
    for ph in $PHASES; do
        case $ph in
            stat|read|grep) maybe_drop ;;
        esac
        t0=$(now_ms)
        "phase_$ph" "$root"
        rc=$?
        t1=$(now_ms)
        ms=$((t1 - t0))
        if [ "$rc" -ne 0 ]; then
            printf '  %-7s %10s  FAILED (rc=%s)\n' "$ph" '-' "$rc"
            eval "R_${tgt}_${ph}=-1"
            continue
        fi
        eval "R_${tgt}_${ph}=$ms"
        extra=''
        case $ph in
            write|read) extra=$(mib_per_sec "$ms" "$TOTAL_BYTES") ;;
        esac
        printf '  %-7s %9ss  %-10s %s\n' "$ph" "$(fmt_ms "$ms")" \
            "$(per_sec "$ms" "$(ops_for "$ph")")" "$extra"
    done
    eval "BYTES_$tgt=$TOTAL_BYTES"
    return 0
}

# ------------------------------------------------------------ target dirs ----

writable_dir() {  # dir -> 0 if we can create entries in it
    d=$1
    [ -d "$d" ] || return 1
    probe="$d/.fs-perf-probe.$$"
    mkdir "$probe" 2>/dev/null || return 1
    rmdir "$probe" 2>/dev/null
    return 0
}

detect_win_base() {
    [ -n "$WIN_DIR" ] && { echo "$WIN_DIR"; return 0; }
    # Windows drives as mounted by WSL: 9p (WSL2) or drvfs (WSL1).
    # WSL exposes Windows drives via 9p (older WSL2), virtiofs (newer WSL2),
    # drvfs (WSL1) or fuseblk, depending on version and /etc/wsl.conf.
    mounts=$(awk '$2 ~ /^\/mnt\/[a-z]$/ &&
        ($3 == "9p" || $3 == "drvfs" || $3 == "virtiofs" || $3 == "fuseblk") { print $2 }' \
        /proc/mounts 2>/dev/null)
    [ -n "$mounts" ] || mounts=$(ls -d /mnt/[a-z] 2>/dev/null)
    for m in $mounts; do
        for c in "$m/Users"/*/AppData/Local/Temp "$m/temp" "$m/Temp" "$m/Users/Public"; do
            case $c in *'*'*) continue ;; esac
            if writable_dir "$c"; then
                echo "$c/fs-perf"
                return 0
            fi
        done
    done
    return 1
}

# ------------------------------------------------------------------- main ----

if [ "$DROP" = 1 ] && [ ! -w /proc/sys/vm/drop_caches ]; then
    printf '%s: --drop-caches needs root, continuing with warm caches\n' "$PROG" >&2
    DROP=0
fi

printf 'fs-perf: %s files in %s dirs\n' "$COUNT" "$DIR_COUNT"
printf 'kernel:  %s\n' "$(uname -sr)"
printf 'distro:  %s\n' "${WSL_DISTRO_NAME:-unknown}"
printf 'cpus:    %s, page cache: %s\n' "$(nproc 2>/dev/null || echo '?')" \
    "$(if [ "$DROP" = 1 ]; then echo dropped; else echo warm; fi)"

for t in $TARGETS; do
    case $t in
        ext4)
            base=${EXT4_DIR:-$HOME/.cache/fs-perf}
            if ! mkdir -p "$base" 2>/dev/null; then
                printf '%s: skipping ext4: cannot create %s\n' "$PROG" "$base" >&2
                continue
            fi
            ROOT_ext4="$base/fsperf-$$"
            RUN_TARGETS="$RUN_TARGETS ext4"
            ;;
        ntfs)
            base=$(detect_win_base) || base=''
            if [ -z "$base" ]; then
                printf '%s: skipping ntfs: no writable Windows dir found (use --win-dir)\n' \
                    "$PROG" >&2
                continue
            fi
            if ! mkdir -p "$base" 2>/dev/null; then
                printf '%s: skipping ntfs: cannot create %s\n' "$PROG" "$base" >&2
                continue
            fi
            ROOT_ntfs="$base/fsperf-$$"
            RUN_TARGETS="$RUN_TARGETS ntfs"
            ;;
        *) die "unknown target: $t (expected ext4 or ntfs)" ;;
    esac
done

RUN_TARGETS=${RUN_TARGETS# }
[ -n "$RUN_TARGETS" ] || die "no usable targets"

cleanup() {
    [ "$KEEP" = 1 ] && return 0
    for t in $RUN_TARGETS; do
        eval "r=\${ROOT_$t:-}"
        [ -n "$r" ] && [ -d "$r" ] && rm -rf "$r"
    done
    return 0
}
trap 'cleanup' EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

build_bodies

for t in $RUN_TARGETS; do
    eval "r=\$ROOT_$t"
    run_target "$t" "$r"
done

# ------------------------------------------------------------------ table ----

ntgt=0
first=''
second=''
for t in $RUN_TARGETS; do
    ntgt=$((ntgt + 1))
    if [ -z "$first" ]; then first=$t; else second=$t; fi
done

printf '\n%-8s' 'phase'
for t in $RUN_TARGETS; do printf '%12s' "$t"; done
[ "$ntgt" -eq 2 ] && printf '%12s' 'slowdown'
printf '\n%-8s' '-------'
for t in $RUN_TARGETS; do printf '%12s' '-----------'; done
[ "$ntgt" -eq 2 ] && printf '%12s' '-----------'
printf '\n'

tot_first=0
tot_second=0
for ph in $PHASES; do
    printf '%-8s' "$ph"
    for t in $RUN_TARGETS; do
        eval "v=\${R_${t}_${ph}:--1}"
        if [ "$v" -lt 0 ]; then
            printf '%12s' 'fail'
        else
            printf '%11ss' "$(fmt_ms "$v")"
            [ "$t" = "$first" ] && tot_first=$((tot_first + v))
            [ "$t" = "$second" ] && tot_second=$((tot_second + v))
        fi
    done
    if [ "$ntgt" -eq 2 ]; then
        eval "a=\${R_${first}_${ph}:--1}; b=\${R_${second}_${ph}:--1}"
        if [ "$a" -lt 0 ] || [ "$b" -lt 0 ]; then
            printf '%12s' '-'
        else
            printf '%12s' "$(ratio "$a" "$b")"
        fi
    fi
    printf '\n'
done

printf '%-8s' 'TOTAL'
for t in $RUN_TARGETS; do
    if [ "$t" = "$first" ]; then
        printf '%11ss' "$(fmt_ms "$tot_first")"
    else
        printf '%11ss' "$(fmt_ms "$tot_second")"
    fi
done
[ "$ntgt" -eq 2 ] && printf '%12s' "$(ratio "$tot_first" "$tot_second")"
printf '\n'

eval "bt=\${BYTES_$first:-0}"
printf '\ncorpus: %s files, %s bytes (%s.%02d MiB)\n' "$COUNT" "$bt" \
    $((bt / 1048576)) $((bt % 1048576 * 100 / 1048576))

if [ -n "$CSV" ]; then
    {
        printf 'target,phase,ms,ops\n'
        for t in $RUN_TARGETS; do
            for ph in $PHASES; do
                eval "v=\${R_${t}_${ph}:--1}"
                printf '%s,%s,%s,%s\n' "$t" "$ph" "$v" "$(ops_for "$ph")"
            done
        done
    } > "$CSV" && printf 'csv: %s\n' "$CSV"
fi

if [ "$KEEP" = 1 ]; then
    printf 'kept:\n'
    for t in $RUN_TARGETS; do
        eval "r=\$ROOT_$t"
        printf '  %s\n' "$r"
    done
fi

printf '\nFor the Windows-side halves of the matrix run fs-perf.ps1 from Windows.\n'
