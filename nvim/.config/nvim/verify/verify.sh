#!/usr/bin/env bash
# Verify this Neovim config in a sandbox profile.
#
# The sandbox has its own XDG directories, so it never touches the plugins
# or state of the profile you actually use. Its config directory is a
# symlink to this one, so edits here take effect immediately with no copy
# step. The plugin clones persist between runs under the cache directory;
# the first run installs them and takes a few minutes.
#
#   ./verify.sh            check the config as lazy-lock.json pins it
#   ./verify.sh --sync     move clones to the specs' commits first, for
#                          checking a pin you changed but have not synced
#   ./verify.sh --clean    discard the sandbox and install from scratch
#
# Exit status is 0 only when every plugin loads, every probe file opens and
# parses, and no plugin reported an error or warning.
set -euo pipefail

config_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=${XDG_CACHE_HOME:-$HOME/.cache}/nvim-config-verify
lazy_op=restore

for arg in "$@"; do
	case $arg in
	--sync) lazy_op=sync ;;
	--clean) rm -rf "$sandbox" ;;
	-h | --help)
		sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "verify.sh: unknown option $arg" >&2
		exit 2
		;;
	esac
done

mkdir -p "$sandbox/config"
ln -sfn "$config_dir" "$sandbox/config/nvim"

export XDG_CONFIG_HOME="$sandbox/config"
export XDG_DATA_HOME="$sandbox/data"
export XDG_STATE_HOME="$sandbox/state"
export XDG_CACHE_HOME="$sandbox/cache"

# The sandbox bootstraps its own lazy.nvim and resolves branch names itself,
# so letting it write lazy-lock.json silently changes pins nobody reviewed.
# Keep the repository's copy byte-for-byte and report if the run moved it.
lock=$config_dir/lazy-lock.json
lock_before=$(mktemp)
cp "$lock" "$lock_before"
restore_lock() {
	if ! cmp -s "$lock" "$lock_before"; then
		echo "note: discarded lazy-lock.json changes made by the sandbox" >&2
		cp "$lock_before" "$lock"
	fi
	rm -f "$lock_before"
}
trap restore_lock EXIT

nvim --headless "+Lazy! $lazy_op" +qa >/dev/null 2>&1 || true

output=$(cd "$config_dir/verify/fixture" &&
	timeout 300 nvim --headless "+luafile $config_dir/verify/check.lua" 2>&1) && status=0 || status=$?

echo "$output" | grep -E '^(  |CHECK)' || echo "$output"

if [ "$status" -eq 0 ]; then
	echo "==> PASS"
else
	echo "==> FAIL"
fi
exit "$status"
