#!/usr/bin/env bats
#
# Guards on the release configuration.
#
# These read files rather than running semantic-release, deliberately. A real
# release needs a token, a remote and a commit worth releasing, so the thing
# worth testing here is not "does the tool work" - it is the handful of settings
# that are wrong in a way nobody notices until a release has already happened.
#
# The tag format is the one that matters. Every tag in this repository carries a
# v prefix, all 50 of them, and semantic-release defaults to that - but eight of
# the other repositories tag bare and need it set to ${version}. Copy a config
# between the two groups without reading this line and the next release here
# starts again at 1.0.0, over a live repository, and the tag it wants is already
# taken. See #16.
#
# The publish step used to be scripts/forgejo-release.js, because there was no
# @semantic-release/forgejo. On GitHub there is a real @semantic-release/github,
# so that script and its dedicated notes-extraction tests are gone with it.

REPO_ROOT="${BATS_TEST_DIRNAME}/.."

@test "the release config tags the way this repository already tags" {
	run grep -F '"tagFormat": "v${version}"' "$REPO_ROOT/.releaserc.json"
	[ "$status" -eq 0 ]
}

@test "nothing in the release config still names GitLab" {
	run grep -ril gitlab "$REPO_ROOT/.releaserc.json" "$REPO_ROOT/package.json"
	[ "$status" -ne 0 ]
}

@test "the release commit tells the pipeline not to run again" {
	# Without [skip ci] the changelog commit starts a pipeline, which releases
	# nothing and costs a full run every time - and the tag push starts one of
	# its own that does have something to do.
	run grep -F '[skip ci]' "$REPO_ROOT/.releaserc.json"
	[ "$status" -eq 0 ]
}

@test "the changelog stays committed at the repo root" {
	[ -f "$REPO_ROOT/CHANGELOG.md" ]
	run grep -F '"@semantic-release/changelog"' "$REPO_ROOT/.releaserc.json"
	[ "$status" -eq 0 ]
	run grep -F 'CHANGELOG.md' "$REPO_ROOT/.releaserc.json"
	[ "$status" -eq 0 ]
}

@test "the release tooling is pinned like everything else" {
	# The house rule is exact versions everywhere. A release tool on a range is
	# the one dependency that can change what it does between two runs nobody
	# is watching.
	local line
	while IFS= read -r line; do
		case "$line" in
		*'"^'* | *'"~'* | *'"*"'* | *latest*)
			echo "unpinned release dependency: $line" >&2
			return 1
			;;
		esac
	done < <(grep -E '"(semantic-release|@semantic-release/[a-z]+)":' "$REPO_ROOT/package.json")
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

@test "the release step disables lefthook before it pushes" {
	# bun install (no --ignore-scripts) runs lefthook's prepare script, so the
	# hook is live in this checkout by the time @semantic-release/git runs a
	# plain `git push` from inside the release job. The pre-push hook shells
	# out to `docker compose run --rm hadolint ...`; this image has no docker,
	# so the hook dies on "docker: command not found" and takes the push - and
	# the whole release - down with it.
	run grep -F 'LEFTHOOK: "0"' "$REPO_ROOT/.github/workflows/ci.yml"
	[ "$status" -eq 0 ]
}

@test "the release config publishes through the real GitHub plugin" {
	run grep -F '"@semantic-release/github"' "$REPO_ROOT/.releaserc.json"
	[ "$status" -eq 0 ]
}
