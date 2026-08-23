#!/bin/sh
# runner-watchdog.sh  (fork-only — see FORK.md)
#
# Thin supervisor around n8n's real task-runner-launcher. It adds ONE behaviour:
# if the task broker becomes permanently unreachable, it makes the container
# EXIT, so Docker's existing `restart: unless-stopped` policy recreates it.
#
# Why: each runner is a sidecar sharing its paired worker's network namespace
# (network_mode: "service:n8n-worker-N", broker at 127.0.0.1:5679). When the
# worker restarts (shared DB restart, OOM, update) the namespace dies and the
# launcher gets stuck forever in "Waiting for task broker" — the process stays
# alive, so `restart: unless-stopped` never fires and the runner is a zombie
# until restarted by hand. Turning that hang into an exit lets the runner be
# recreated into the worker's CURRENT namespace, where it reconnects.
#
# No new mechanism is added: the restart itself is Docker's (restart policy),
# the signals are the OS's, the reconnect is n8n's. This script only decides
# WHEN to let Docker act — and only after the launcher's own reconnect loop has
# clearly failed. It never interrupts a live task: it acts solely while the
# broker (hence the worker) is already gone.
#
# Disable entirely with RUNNER_WATCHDOG_ENABLED=false (pass-through mode).

REAL="/usr/local/bin/task-runner-launcher.real"

# Pass-through: behave byte-for-byte like the stock launcher.
if [ "${RUNNER_WATCHDOG_ENABLED:-true}" != "true" ]; then
    exec "$REAL" "$@"
fi

BROKER_URI="${N8N_RUNNERS_TASK_BROKER_URI:-http://127.0.0.1:5679}"
GRACE="${RUNNER_BROKER_GRACE:-120}"               # seconds broker may stay down
INTERVAL="${RUNNER_BROKER_CHECK_INTERVAL:-15}"    # seconds between probes

# Run the real launcher as a child so we can watch it and forward signals.
"$REAL" "$@" &
LAUNCHER_PID=$!

# Keep `docker stop`/`restart` graceful: pass the signal on to the launcher,
# wait for it to finish, then exit ourselves.
forward_term() {
    kill -TERM "$LAUNCHER_PID" 2>/dev/null
    wait "$LAUNCHER_PID" 2>/dev/null
    exit 0
}
trap forward_term TERM INT

# broker_up: true if the broker answers HTTP at all (any status, incl. 404).
# busybox wget prints the "HTTP/..." status line on an HTTP response and a
# "can't connect"/timeout message otherwise, so grepping for "HTTP/" cleanly
# distinguishes "TCP reachable" from "unreachable".
broker_up() {
    wget -T 3 -O /dev/null "$BROKER_URI" 2>&1 | grep -q 'HTTP/'
}

connected=0    # start the countdown only after the first successful connect, so
down=0         # normal startup (broker not ready yet) is never punished.

while kill -0 "$LAUNCHER_PID" 2>/dev/null; do
    if broker_up; then
        connected=1
        down=0
    elif [ "$connected" = 1 ]; then
        down=$((down + INTERVAL))
        if [ "$down" -ge "$GRACE" ]; then
            echo "[runner-watchdog] broker $BROKER_URI unreachable for ${down}s;" \
                 "stopping launcher so Docker recreates the runner" >&2
            kill -TERM "$LAUNCHER_PID" 2>/dev/null
            wait "$LAUNCHER_PID" 2>/dev/null
            exit 1
        fi
    fi
    sleep "$INTERVAL"
done

# Launcher exited on its own — mirror its exit code.
wait "$LAUNCHER_PID"
