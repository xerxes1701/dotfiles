#!/usr/bin/env bash
#
# find-keybind.sh
#
# Query keybindings.yaml for entries matching any combination of filters.
#
# By default it searches ALL binding types — the explicit config maps
# (`keybindings`), the plugin defaults (`default_bindings`) and the Neovim
# built-ins (`builtin_bindings`) — and prints the matching entries as a JSON
# array.
#
# Filters (all optional, all combinable with logical AND):
#   * key      positional, case-insensitive, angle brackets optional
#   * mode     -m/--mode      repeatable; matches the compound `mode` field
#   * type     -t/--type      repeatable; binding type / source value
#   * plugin   -p/--plugin    repeatable; exact (case-insensitive) plugin
#   * group    -g/--group     repeatable; exact (case-insensitive) group
#   * file     -f/--file      repeatable; GLOB against the `file` field
# Repeating an option ORs its values; different options AND together.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
YAML_FILE="${SCRIPT_DIR}/keybindings.yaml"

# Valid Vim modes and binding types recognised in keybindings.yaml.
VALID_MODES=(n i c v x o t)
VALID_TYPES=(explicit default builtin)

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [key]

Search keybindings.yaml across all binding types (explicit config maps, plugin
defaults and Neovim built-ins), filtering by any combination of criteria.

Arguments:
  key                   Optional key sequence to search for (e.g. "<C-S>",
                        "C-s"). Matching is case-insensitive and the surrounding
                        angle brackets are optional. If omitted, keys are not
                        filtered.

Options:
  -m, --mode <mode>     Restrict to a Vim mode. Repeatable (any-of). The stored
                        compound mode field (e.g. "n,x,o") is treated as a list.
                        Valid modes: ${VALID_MODES[*]}.
  -t, --type <type>     Restrict to a binding type (the \`source\` field).
      --source <type>   Alias of --type. Repeatable (any-of).
                        Valid types: ${VALID_TYPES[*]}.
  -p, --plugin <name>   Restrict to a plugin (exact, case-insensitive).
                        Repeatable (any-of).
  -g, --group <name>    Restrict to a logical group (exact, case-insensitive).
                        Repeatable (any-of).
  -f, --file <glob>     Restrict to a source file matched by a shell-style glob
                        (e.g. "lua/plugins/*.lua"). Repeatable (any-of).
      --input <path>    keybindings YAML file to read
                        (default: ${YAML_FILE}).
  -h, --help            Show this help and exit.

Examples:
  ${SCRIPT_NAME} '<C-S>'
  ${SCRIPT_NAME} -m n -m i '<C-S>'
  ${SCRIPT_NAME} --type builtin -m o          # all built-in operator-pending keys
  ${SCRIPT_NAME} -p flash.nvim                # everything from one plugin
  ${SCRIPT_NAME} -g Editing --type explicit   # explicit editing maps
  ${SCRIPT_NAME} -f 'lua/plugins/*.lua'       # maps defined under lua/plugins

Exit status:
  0  one or more matching entries were found
  1  no matching entries were found
  2  invalid usage or arguments
EOF
}

die() {
  printf '%s: error: %s\n\n' "${SCRIPT_NAME}" "$1" >&2
  usage >&2
  exit 2
}

in_list() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [[ "${needle}" == "${x}" ]] && return 0; done
  return 1
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Escape a value for safe embedding inside a jq double-quoted string literal.
jq_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# Convert a shell-style glob into an anchored, case-insensitive jq regex.
glob_to_regex() {
  local g="$1" out="" i c
  for ((i = 0; i < ${#g}; i++)); do
    c="${g:i:1}"
    case "${c}" in
      '*') out+='.*' ;;
      '?') out+='.' ;;
      '.'|'('|')'|'['|']'|'{'|'}'|'+'|'^'|'$'|'|'|'\\') out+="\\${c}" ;;
      *) out+="${c}" ;;
    esac
  done
  printf '(?i)^%s$' "${out}"
}

main() {
  local key="" have_key=0
  local -a modes=() types=() plugins=() groups=() fileglobs=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -m|--mode)
        [[ $# -ge 2 ]] || die "option '$1' requires an argument"
        in_list "$2" "${VALID_MODES[@]}" || die "invalid mode '$2' (valid: ${VALID_MODES[*]})"
        modes+=("$2"); shift 2 ;;
      --mode=*)
        local v="${1#*=}"; in_list "${v}" "${VALID_MODES[@]}" || die "invalid mode '${v}' (valid: ${VALID_MODES[*]})"
        modes+=("${v}"); shift ;;
      -t|--type|--source)
        [[ $# -ge 2 ]] || die "option '$1' requires an argument"
        local v; v="$(lower "$2")"; in_list "${v}" "${VALID_TYPES[@]}" || die "invalid type '$2' (valid: ${VALID_TYPES[*]})"
        types+=("${v}"); shift 2 ;;
      -t=*|--type=*|--source=*)
        local v; v="$(lower "${1#*=}")"; in_list "${v}" "${VALID_TYPES[@]}" || die "invalid type '${1#*=}' (valid: ${VALID_TYPES[*]})"
        types+=("${v}"); shift ;;
      -p|--plugin)
        [[ $# -ge 2 ]] || die "option '$1' requires an argument"
        [[ -n "$2" ]] || die "option '$1' requires a non-empty value"
        plugins+=("$2"); shift 2 ;;
      --plugin=*)
        [[ -n "${1#*=}" ]] || die "option '--plugin' requires a non-empty value"
        plugins+=("${1#*=}"); shift ;;
      -g|--group)
        [[ $# -ge 2 ]] || die "option '$1' requires an argument"
        [[ -n "$2" ]] || die "option '$1' requires a non-empty value"
        groups+=("$2"); shift 2 ;;
      --group=*)
        [[ -n "${1#*=}" ]] || die "option '--group' requires a non-empty value"
        groups+=("${1#*=}"); shift ;;
      -f|--file)
        [[ $# -ge 2 ]] || die "option '$1' requires an argument"
        [[ -n "$2" ]] || die "option '$1' requires a non-empty value"
        fileglobs+=("$2"); shift 2 ;;
      --file=*)
        [[ -n "${1#*=}" ]] || die "option '--file' requires a non-empty value"
        fileglobs+=("${1#*=}"); shift ;;
      --input)
        [[ $# -ge 2 ]] || die "option '$1' requires an argument"
        YAML_FILE="$2"; shift 2 ;;
      --input=*)
        YAML_FILE="${1#*=}"; shift ;;
      --) shift; break ;;
      -*) die "unknown option '$1'" ;;
      *)
        [[ ${have_key} -eq 0 ]] || die "unexpected extra argument '$1' (key already set to '${key}')"
        key="$1"; have_key=1; shift ;;
    esac
  done
  while [[ $# -gt 0 ]]; do
    [[ ${have_key} -eq 0 ]] || die "unexpected extra argument '$1' (key already set to '${key}')"
    key="$1"; have_key=1; shift
  done

  [[ ${have_key} -eq 0 || -n "${key}" ]] || die "key argument must not be empty"

  command -v yq >/dev/null 2>&1 || die "'yq' is not installed or not on PATH"
  [[ -f "${YAML_FILE}" ]] || die "keybindings file not found: ${YAML_FILE}"

  # ---- assemble the jq filter conditions ----------------------------- #
  local -a conds=()

  if [[ ${have_key} -eq 1 ]]; then
    local bare="${key#<}"; bare="${bare%>}"
    local esc; esc="$(printf '%s' "${bare}" | sed -E 's/[][(){}.^$*+?|\\]/\\&/g')"
    conds+=("(.key | test(\"(?i)^<?${esc}>?\$\"))")
  fi

  if [[ ${#modes[@]} -gt 0 ]]; then
    local c="" m
    for m in "${modes[@]}"; do [[ -n "${c}" ]] && c+=" or "; c+=". == \"${m}\""; done
    conds+=("(.mode | split(\",\") | any(${c}))")
  fi

  if [[ ${#types[@]} -gt 0 ]]; then
    local c="" t
    for t in "${types[@]}"; do [[ -n "${c}" ]] && c+=" or "; c+="\$s == \"${t}\""; done
    conds+=("((.source // \"explicit\" | ascii_downcase) as \$s | (${c}))")
  fi

  if [[ ${#plugins[@]} -gt 0 ]]; then
    local c="" p
    for p in "${plugins[@]}"; do [[ -n "${c}" ]] && c+=" or "; c+="\$p == \"$(jq_escape "$(lower "${p}")")\""; done
    conds+=("((.plugin // \"\" | ascii_downcase) as \$p | (${c}))")
  fi

  if [[ ${#groups[@]} -gt 0 ]]; then
    local c="" g
    for g in "${groups[@]}"; do [[ -n "${c}" ]] && c+=" or "; c+="\$g == \"$(jq_escape "$(lower "${g}")")\""; done
    conds+=("((.group // \"\" | ascii_downcase) as \$g | (${c}))")
  fi

  if [[ ${#fileglobs[@]} -gt 0 ]]; then
    local c="" fg re
    for fg in "${fileglobs[@]}"; do
      re="$(jq_escape "$(glob_to_regex "${fg}")")"
      [[ -n "${c}" ]] && c+=" or "
      c+="(.file | test(\"${re}\"))"
    done
    conds+=("(${c})")
  fi

  local select_expr="true"
  if [[ ${#conds[@]} -gt 0 ]]; then
    local IFS=$'\n'
    select_expr="$(printf '%s and ' "${conds[@]}")"
    select_expr="${select_expr% and }"
  fi

  local jq_filter="
    [ ( (.keybindings // []) + (.default_bindings // []) + (.builtin_bindings // []) )[]
      | select(${select_expr})
    ]
  "

  local result
  if ! result="$(yq "${jq_filter}" "${YAML_FILE}" 2>&1)"; then
    printf '%s\n' "${result}" >&2
    die "yq query failed"
  fi

  printf '%s\n' "${result}"

  local count
  count="$(printf '%s' "${result}" | yq 'length' -)"
  [[ "${count}" -gt 0 ]] || return 1
  return 0
}

main "$@"
