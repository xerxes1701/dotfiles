#!/usr/bin/env bash
# Run the self-hosted Atuin AI server in rootless podman, with the Anthropic
# API key from 1Password.
#
#   atuin-ai-server.sh start    read the key (1Password asks to approve), start
#   atuin-ai-server.sh stop     stop the server and delete the key file
#   atuin-ai-server.sh status   is it running
#   atuin-ai-server.sh logs     follow its log
#
# The key goes from `op read` into a file in $XDG_RUNTIME_DIR -- tmpfs, in a
# directory only this user can enter, gone at reboot -- which is mounted
# read-only into the container, where the server `cat`s it (ai-server.toml).
# It is never an environment variable or a command-line argument, so neither
# `ps` nor `podman inspect` shows it. Run `start` again after a reboot.
#
# ATUIN_AI_KEY_REF names the 1Password field; the default below is this
# machine's. The server listens on 127.0.0.1 only.

set -euo pipefail

ref=${ATUIN_AI_KEY_REF:-"op://Personal/Claude API Key - Atuin/credential"}
name=atuin-ai-server
image=ghcr.io/atuinsh/atuin-ai-server:latest
port=8788
config=$HOME/.config/atuin/ai-server.toml
dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$name
key=$dir/anthropic-api-key

usage() { sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; }

start() {
    command -v podman >/dev/null || { echo "podman is not installed" >&2; exit 1; }
    [ -f "$config" ] || { echo "no server config at $config -- is the atuin package deployed?" >&2; exit 1; }

    install -d -m 700 "$dir"
    (
        umask 077
        op read --no-newline "$ref" >"$key.new"
    ) || { rm -f "$key.new"; echo "could not read $ref from 1Password" >&2; exit 1; }
    [ -s "$key.new" ] || { rm -f "$key.new"; echo "$ref is empty" >&2; exit 1; }
    mv -f "$key.new" "$key"

    # --user 0 is this user, not root: rootless podman maps the container's
    # root to the invoking uid, which is what lets the server read the 0600
    # key file. Nothing else about the container needs privileges.
    podman run -d --rm --replace --name "$name" \
        --user 0 --cap-drop all --security-opt no-new-privileges \
        -p "127.0.0.1:$port:8080" \
        -v "$(readlink -f "$config"):/etc/atuin-ai/config.toml:ro,Z" \
        -v "$key:/run/secrets/anthropic-api-key:ro,Z" \
        "$image" >/dev/null
    echo "atuin ai server on http://127.0.0.1:$port"
}

stop() {
    podman stop --ignore "$name" >/dev/null 2>&1 || true
    rm -f "$key"
    echo "stopped; key file removed"
}

status() {
    if podman container exists "$name" 2>/dev/null; then
        podman ps --filter "name=^$name\$" --format '{{.Names}}  {{.Status}}  {{.Ports}}'
    else
        echo "not running"
        return 1
    fi
}

case ${1:-} in
    start) start ;;
    stop) stop ;;
    status) status ;;
    logs) exec podman logs -f "$name" ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 2 ;;
esac
