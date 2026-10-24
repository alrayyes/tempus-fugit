#!/usr/bin/env bash
# The e2e job runs in ghcr.io/alrayyes/ci-playwright, so no job downloads a
# browser or runs apt. The image's browsers only work with the library version
# they were built for, and a workflow can't read bun.lock, so the tag is written
# out in ci.yml. This fails when the image tag drifts from the @playwright/test
# version in bun.lock, when the pin lacks a digest, when the container lacks
# --ipc=host, or when a `playwright install` step comes back. Dependabot can't
# see an image named in a workflow, so this is what keeps the two in step.
# WORKFLOW and LOCKFILE override the files checked.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

workflow=${WORKFLOW:-.github/workflows/ci.yml}
lockfile=${LOCKFILE:-bun.lock}

failed=0
fail() {
	echo "FAIL: $1"
	failed=1
}

locked=$(grep -Eo '"@playwright/test@[0-9]+\.[0-9]+\.[0-9]+"' "$lockfile" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
[ -n "$locked" ] || fail "$lockfile locks no exact @playwright/test version"

images=()
while IFS= read -r line; do
	images+=("$line")
done < <(grep -E '^\s+image: ghcr\.io/alrayyes/ci-playwright:' "$workflow" | sed -E 's/^\s+image: //' || true)
[ "${#images[@]}" -ge 1 ] || fail "$workflow has no job on the ci-playwright image"

for image in "${images[@]}"; do
	if ! [[ $image =~ ^ghcr\.io/alrayyes/ci-playwright:([0-9]+\.[0-9]+\.[0-9]+)@sha256:[0-9a-f]{64}$ ]]; then
		fail "image '$image' is not pinned by an exact version and a digest (X.Y.Z@sha256:...)"
		continue
	fi
	if [ "${BASH_REMATCH[1]}" != "$locked" ]; then
		fail "image '$image' is for Playwright ${BASH_REMATCH[1]}, but $lockfile locks @playwright/test $locked"
	fi
done

if [ "${#images[@]}" -gt 0 ] && [ "$(printf '%s\n' "${images[@]}" | sort -u | wc -l)" -gt 1 ]; then
	fail "the jobs use different Playwright images: ${images[*]}"
fi

if [ "$(grep -Ec '^\s+options: .*--ipc=host' "$workflow" || true)" -lt "${#images[@]}" ]; then
	fail "every job on the ci-playwright image needs 'options: --ipc=host'"
fi

if grep -Eq 'playwright install' "$workflow"; then
	fail "$workflow still runs 'playwright install'; the image already has the browsers"
fi

exit "$failed"
