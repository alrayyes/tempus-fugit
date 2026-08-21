#!/usr/bin/env bash
#
# Coverage over test/release.bats, the closest thing this repo has to
# application source now that @semantic-release/github replaced the old
# scripts/forgejo-release.js publish step - it's real bash with loops and a
# case statement, not just config or markup. test/smoke.bats stays out of
# this: it needs a docker socket to build and run the served container, and
# the kcov image carries no docker CLI to reach one from inside itself.
#
# bats-core preprocesses a test file into a numbered copy under $TMPDIR
# before running it, which is the file kcov actually traces. Pinning TMPDIR
# under the workspace keeps that copy inside the volume kcov can see, and
# the sed below rewrites the numbered name back to the real path afterwards
# - otherwise Codecov reports coverage against a temp file nobody can look
# up instead of test/release.bats.
set -euo pipefail

mkdir -p .bats-tmp coverage

docker compose run --rm -T -u "$(id -u):$(id -g)" \
	-e TMPDIR=/app/.bats-tmp \
	kcov \
	kcov --include-pattern=.bats.src /app/coverage \
	node_modules/bats/bin/bats test/release.bats

report="$(find coverage -name cobertura.xml)"
sed -i -E 's#filename="(.*/)?[0-9]+-([a-z]+)\.bats\.src"#filename="test/\2.bats"#g' "$report"
cp "$report" coverage/cobertura.xml
