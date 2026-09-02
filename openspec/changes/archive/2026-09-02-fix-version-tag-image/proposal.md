## Why

`migrate-release-please` (merged) missed a consequence of dropping
`RELEASE_TOKEN`: GitHub suppresses any new workflow run triggered by
`GITHUB_TOKEN`'s own actions, tag creation included. `RELEASE_TOKEN` was a
real PAT, so the version tag it pushed _did_ start a fresh run — which is
what published the version-tagged GHCR image (`ghcr.io/…:v1.3.0`). With
release-please creating that tag via the API using `GITHUB_TOKEN`, that
second run never fires, so the `image` job — which only ever runs in the
run that pushed a ref, and only tags with `github.ref_name` — never sees a
version-tag ref and never publishes one. The first real release under the
new setup would ship no version-tagged image, silently, the same failure
shape `rules/go-releases.md` already documents for goreleaser under
release-please.

## What Changes

- A new `retag-release-image` job in `ci.yml`, `needs: [release, image]`,
  gated on `needs.release.outputs.release_created == 'true'`. It doesn't
  rebuild — `docker buildx imagetools create` copies the manifest `image`
  already pushed under `:latest` to a new tag matching
  `needs.release.outputs.tag_name`, in the same workflow run that cut the
  release.
- `test/release.bats` gets a matching assertion.
- `openspec/specs/deploy/spec.md`'s "Push a version tag" scenario is
  corrected — it described a separate tag-triggered run publishing the
  image, which was only ever true for `RELEASE_TOKEN`'s PAT-driven tags
  and is no longer how this works.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `deploy`: the version-tagged image now comes from `retag-release-image`
  retagging the same run's `:latest` build, not from a second run
  triggered by the tag push itself.

## Impact

- `.github/workflows/ci.yml`: new job, no changes to `image` or `release`.
- `test/release.bats`: one new test.
- `openspec/specs/deploy/spec.md`: one scenario corrected via delta.
- Not yet observed live — this fixes a mechanism gap found by re-reading
  `rules/go-releases.md` before the first real release-please cycle
  completed, not a failure that already happened.
