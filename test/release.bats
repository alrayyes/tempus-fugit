#!/usr/bin/env bats
#
# Guards on the release configuration.
#
# These read files rather than running release-please, deliberately. A real
# release needs a pull request, checks passing and something to merge it -
# the thing worth testing here is not "does the tool work", it is the
# handful of settings that are wrong in a way nobody notices until a
# release has already happened.
#
# The tag format is the one that matters most. Every tag in this repository
# carries a v prefix, all 50 of them from before this migration, and
# release-please defaults to a component-prefixed tag
# (tempus-fugit-v1.3.0) the moment a package name exists, which
# package.json's does. See #16 for the semantic-release-era version of this
# exact trap, and openspec/specs/release/spec.md for what replaced it.

REPO_ROOT="${BATS_TEST_DIRNAME}/.."

@test "the release config keeps tags v-prefixed, not component-prefixed" {
	run grep -F '"include-component-in-tag": false' "$REPO_ROOT/release-please-config.json"
	[ "$status" -eq 0 ]
}

@test "the release config uses the node release type" {
	run grep -F '"release-type": "node"' "$REPO_ROOT/release-please-config.json"
	[ "$status" -eq 0 ]
}

@test "the release manifest is seeded, not left to bootstrap from zero" {
	run grep -E '"\.": *"[0-9]+\.[0-9]+\.[0-9]+"' "$REPO_ROOT/.release-please-manifest.json"
	[ "$status" -eq 0 ]
}

@test "nothing in the release config still names GitLab" {
	run grep -ril gitlab \
		"$REPO_ROOT/release-please-config.json" \
		"$REPO_ROOT/.release-please-manifest.json" \
		"$REPO_ROOT/package.json"
	[ "$status" -ne 0 ]
}

@test "no leftover semantic-release config or dependency" {
	[ ! -f "$REPO_ROOT/.releaserc.json" ]
	run grep -E '"(semantic-release|@semantic-release/[a-z]+)":' "$REPO_ROOT/package.json"
	[ "$status" -ne 0 ]
}

@test "the release action is pinned by commit SHA, like everything else" {
	# The house rule is exact versions everywhere - a floating major tag on the
	# one action that can cut a release is the one dependency that can change
	# what it does between two runs nobody is watching.
	run grep -E 'googleapis/release-please-action@[0-9a-f]{40} # v[0-9]' \
		"$REPO_ROOT/.github/workflows/ci.yml"
	[ "$status" -eq 0 ]
}

@test "the release job only ever runs on the default branch" {
	# The whole job, from its name to the start of the next one, so this does not
	# break the next time Prettier decides how to lay the `needs` list out.
	local job
	job="$(awk '/^  release:/ {found=1} found && /^  [a-z]+:/ && !/^  release:/ {exit} found' \
		"$REPO_ROOT/.github/workflows/ci.yml")"

	[ -n "$job" ]
	[[ "$job" == *"github.ref == 'refs/heads/master'"* ]]
	[[ "$job" == *"github.event_name == 'push'"* ]]
}

@test "the release job never pushes directly to master" {
	# The whole reason this isn't semantic-release: protect-master's ruleset
	# only bypasses Ryan's own user account, never GITHUB_TOKEN. A `git push`
	# reappearing in this job is the release breaking the same way again.
	local job
	job="$(awk '/^  release:/ {found=1} found && /^  [a-z]+:/ && !/^  release:/ {exit} found' \
		"$REPO_ROOT/.github/workflows/ci.yml")"

	[[ "$job" != *"RELEASE_TOKEN"* ]]
	[[ "$job" != *"git push"* ]]
}

@test "the release pull request auto-merges itself" {
	[ -f "$REPO_ROOT/.github/workflows/release-auto-merge.yml" ]
	run grep -F 'gh pr merge --auto --squash' "$REPO_ROOT/.github/workflows/release-auto-merge.yml"
	[ "$status" -eq 0 ]
}

@test "the auto-merge title match agrees with the configured PR title pattern" {
	# Both sides of this match are supposed to be decided in release-please-config.json
	# alone - if the pattern there ever changes, this catches the workflow's own
	# startsWith check silently going stale instead of ever matching again.
	run grep -F 'chore(release):' "$REPO_ROOT/release-please-config.json"
	[ "$status" -eq 0 ]
	run grep -F 'chore(release):' "$REPO_ROOT/.github/workflows/release-auto-merge.yml"
	[ "$status" -eq 0 ]
}

@test "the screenshot is committed and only updates on an actual release" {
	[ -f "$REPO_ROOT/.github/screenshot.jpg" ]
	local job
	job="$(awk '/^  screenshot:/ {found=1} found && /^  [a-z]+:/ && !/^  screenshot:/ {exit} found' \
		"$REPO_ROOT/.github/workflows/ci.yml")"

	[ -n "$job" ]
	[[ "$job" == *"needs: [release]"* ]]
	[[ "$job" == *"needs.release.outputs.release_created == 'true'"* ]]
}

@test "the screenshot step disables lefthook before it pushes" {
	# bun install (no --ignore-scripts) runs lefthook's prepare script, so the
	# hook is live in this checkout by the time the screenshot job pushes its
	# branch. The pre-push hook shells out to `docker compose run --rm
	# hadolint ...`; this image has no docker, so the hook dies on "docker:
	# command not found" and takes the push down with it.
	run grep -F 'LEFTHOOK: "0"' "$REPO_ROOT/.github/workflows/ci.yml"
	[ "$status" -eq 0 ]
}
