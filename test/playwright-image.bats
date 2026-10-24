#!/usr/bin/env bats
#
# Guards on the Playwright image the e2e job runs in.
#
# The image's browsers only work with the @playwright/test version they were
# built for, and a workflow can't read bun.lock, so the tag is written out in
# ci.yml. scripts/test-playwright-image.sh fails when the two drift. These
# tests run it against the real files and against fixtures that break one rule
# each.

REPO_ROOT="${BATS_TEST_DIRNAME}/.."
SCRIPT="$REPO_ROOT/scripts/test-playwright-image.sh"
DIGEST="sha256:e44eec3f49f8fad2dbfb926fd8cbd0cadf1b9ebca94a960a45daac90a3bd9258"

setup() {
	WORK="$(mktemp -d)"
	cat >"$WORK/bun.lock" <<'LOCK'
    "@playwright/test": ["@playwright/test@1.64.1", "", { "dependencies": { "playwright": "1.64.1" } }, "sha512-x"],
LOCK
	cat >"$WORK/ci.yml" <<YML
jobs:
  e2e:
    container:
      image: ghcr.io/alrayyes/ci-playwright:1.64.1@$DIGEST
      options: --ipc=host
    steps:
      - run: bun run test:e2e
YML
}

teardown() {
	rm -rf "$WORK"
}

check() {
	WORKFLOW="$WORK/ci.yml" LOCKFILE="$WORK/bun.lock" run "$SCRIPT"
}

@test "the real workflow and lockfile agree" {
	run "$SCRIPT"
	[ "$status" -eq 0 ]
}

@test "matching tag and lockfile pass" {
	check
	[ "$status" -eq 0 ]
}

@test "a tag that differs from the lockfile fails and names both versions" {
	sed -i 's/ci-playwright:1.64.1/ci-playwright:1.64.0/' "$WORK/ci.yml"
	check
	[ "$status" -ne 0 ]
	[[ "$output" == *"1.64.0"* ]]
	[[ "$output" == *"1.64.1"* ]]
}

@test "a tag without a digest fails" {
	sed -i "s/@$DIGEST//" "$WORK/ci.yml"
	check
	[ "$status" -ne 0 ]
}

@test "a missing --ipc=host fails" {
	sed -i '/--ipc=host/d' "$WORK/ci.yml"
	check
	[ "$status" -ne 0 ]
}

@test "no job on the image fails" {
	sed -i '/image:/d' "$WORK/ci.yml"
	check
	[ "$status" -ne 0 ]
}

@test "a playwright install step coming back fails" {
	echo "      - run: bunx playwright install --with-deps chromium" >>"$WORK/ci.yml"
	check
	[ "$status" -ne 0 ]
}
