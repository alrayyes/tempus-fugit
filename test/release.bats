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
	# only bypasses Ryan's own user account, never a workflow token. A
	# `git push` reappearing in this job is the release breaking the same
	# way again. RELEASE_TOKEN itself is expected here now (see below) --
	# release-please-action uses it to open a pull request via the API, not
	# to push directly, which is a different thing from the push this test
	# actually guards against.
	local job
	job="$(awk '/^  release:/ {found=1} found && /^  [a-z]+:/ && !/^  release:/ {exit} found' \
		"$REPO_ROOT/.github/workflows/ci.yml")"

	[[ "$job" != *"git push"* ]]
}

@test "release-please authenticates as a real identity, not GITHUB_TOKEN" {
	# A release pull request authored by GITHUB_TOKEN sits at
	# action_required with zero jobs run -- GitHub's fork-PR-workflow
	# approval gate treats a token-authored PR like an outside
	# contributor's, even on the repo's own branch. Confirmed live on #38.
	local job
	job="$(awk '/^  release:/ {found=1} found && /^  [a-z]+:/ && !/^  release:/ {exit} found' \
		"$REPO_ROOT/.github/workflows/ci.yml")"

	[[ "$job" == *"RELEASE_TOKEN"* ]]
}

@test "the release pull request auto-merges itself" {
	[ -f "$REPO_ROOT/.github/workflows/release-auto-merge.yml" ]
	run grep -F 'gh pr merge --auto --squash' "$REPO_ROOT/.github/workflows/release-auto-merge.yml"
	[ "$status" -eq 0 ]
	# Same real-identity requirement as the release job itself: a
	# GITHUB_TOKEN-performed merge suppresses the push event that fires
	# the release job's own on:push trigger for the next cycle.
	run grep -F 'RELEASE_TOKEN' "$REPO_ROOT/.github/workflows/release-auto-merge.yml"
	[ "$status" -eq 0 ]
}

@test "the auto-merge gate matches release-please's own label, not a title pattern" {
	# release-please labels its own pull request "autorelease: pending" --
	# checking that label instead of a title string means there's no second
	# place (release-please-config.json's pull-request-title-pattern) that
	# has to be kept in sync with this workflow by hand.
	run grep -F 'autorelease: pending' "$REPO_ROOT/.github/workflows/release-auto-merge.yml"
	[ "$status" -eq 0 ]
	run grep -F 'pull-request-title-pattern' "$REPO_ROOT/release-please-config.json"
	[ "$status" -ne 0 ]
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

@test "the release image gets a version tag without a second tag-triggered run" {
	# A tag release-please creates via the API never starts a new workflow run
	# of its own - GitHub's recursion guard suppresses that regardless of
	# which token pushed it. This job runs inline in the same workflow
	# invocation instead of depending on that trigger firing at all.
	local job
	job="$(awk '/^  retag-release-image:/ {found=1} found && /^  [a-z-]+:/ && !/^  retag-release-image:/ {exit} found' \
		"$REPO_ROOT/.github/workflows/ci.yml")"

	[ -n "$job" ]
	[[ "$job" == *"needs: [release, image]"* ]]
	[[ "$job" == *"needs.release.outputs.release_created == 'true'"* ]]
	[[ "$job" == *"docker buildx imagetools create"* ]]
}
