#!/usr/bin/env bash
#
# astro preview's daemonizing (Astro 7) is inconsistent across environments -
# it detaches and hands back control once the server is listening on some
# hosts, but blocks in the foreground on GitHub's runners. Backgrounding it
# ourselves and polling over HTTP works either way, instead of relying on
# the command to return on its own. No Playwright `webServer` block for the
# same reason: that option expects its command to block in the foreground,
# which this can't promise.
set -uo pipefail

bun run preview --port 4322 &
preview_pid=$!

ready=0
for _ in $(seq 1 30); do
	if curl -fsS http://localhost:4322/ >/dev/null 2>&1; then
		ready=1
		break
	fi
	sleep 0.5
done

if [ "$ready" -ne 1 ]; then
	echo "preview server never came up at http://localhost:4322" >&2
	kill "$preview_pid" 2>/dev/null
	exit 1
fi

bunx playwright test
status=$?

# Whichever mode it ran in this time: kill it directly if it's still attached
# to $preview_pid, and ask astro's own tracking to stop it in case it detached.
kill "$preview_pid" 2>/dev/null
bunx astro preview stop >/dev/null 2>&1

exit "$status"
