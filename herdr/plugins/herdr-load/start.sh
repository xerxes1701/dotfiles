#!/bin/sh
# Starts herdr-load for the herdr server in HERDR_SOCKET_PATH, detached, and
# returns at once; "restart" stops a running one first, "stop" only stops it.
# herdr-load holds a lock per server, so starting it twice is harmless.
set -eu
root=${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")" && pwd)}
state=${HERDR_PLUGIN_STATE_DIR:-$HOME/.local/state/herdr-load}
pidfile="$state/reporter$(printf %s "$HERDR_SOCKET_PATH" | tr / _).pid"

case ${1:-start} in
restart | stop)
    pid=$(cat "$pidfile" 2>/dev/null || true)
    # Only our reporter: a pid left in the file may belong to anyone by now.
    if [ -n "$pid" ] && [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = herdr-load ]; then
        kill "$pid"
        while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
    fi
    [ "$1" = stop ] && exit 0
    ;;
esac

if [ ! -x "$root/bin/herdr-load" ]; then
    echo "herdr-load is not built yet: run $root/build.sh" >&2
    exit 1
fi
mkdir -p "$state"
# Without the pane's ids: started from an action, the reporter and its
# Windows helper would otherwise count towards that pane's workspace.
env -u HERDR_WORKSPACE_ID -u HERDR_TAB_ID -u HERDR_PANE_ID \
    setsid -f "$root/bin/herdr-load" run </dev/null >>"$state/herdr-load.log" 2>&1
