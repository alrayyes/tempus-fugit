#!/usr/bin/env bash
#
# astro preview daemonizes itself as of Astro 7 and only returns once the
# server is actually listening, unlike most dev servers - so there is no
# polling loop here, and no Playwright `webServer` block either, since that
# option expects the given command to block in the foreground rather than
# hand back a detached pid. Stop it even if the suite fails, or a rerun
# fights over the port.
set -euo pipefail

bun run preview --port 4322

status=0
bunx playwright test || status=$?

bunx astro preview stop

exit "$status"
