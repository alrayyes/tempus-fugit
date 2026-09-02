## Why

Every push to `master` has failed the `release` job's checkout step since
2026-08-22 (#36): `RELEASE_TOKEN`, a fine-grained PAT scoped to Ryan's own
account, is rejected. Nothing has actually released in over a week. The PAT
works only because it authenticates as Ryan's user, who is the sole entry on
`protect-master`'s ruleset `bypass_actors` — `GITHUB_TOKEN` authenticates as
`github-actions[bot]`, which isn't on that list, so it can't push directly to
the protected branch either. Rotating the PAT fixes this once; it doesn't
stop it needing rotation again.

release-please avoids the problem structurally: it proposes a version bump
as a pull request and creates the GitHub Release/tag through the API, never
via a direct `git push` to `master`. Merging a PR doesn't need a ruleset
bypass — this repo's ruleset already requires zero approving reviews, so
`GITHUB_TOKEN` can merge it like any other automated PR (the same mechanism
`dependabot-auto-merge.yml` already uses). No PAT, nothing to rotate, ever.

## What Changes

- Replace `semantic-release` (`.releaserc.json`, `@semantic-release/*`
  devDependencies) with `release-please` (`release-please-config.json`,
  `.release-please-manifest.json`, `googleapis/release-please-action`).
- The `release` job in `ci.yml` runs release-please-action instead of
  `semantic-release`, authenticated with `GITHUB_TOKEN` — `RELEASE_TOKEN` is
  no longer read anywhere in the pipeline.
- A new `release-auto-merge.yml` workflow arms `gh pr merge --auto --squash`
  on release-please's own pull request the moment it's opened or updated,
  matching its title prefix — mirrors `dependabot-auto-merge.yml`'s existing
  actor-gated pattern.
- **BREAKING (internal only, no external consumer)**: the screenshot
  (`.github/screenshot.jpg`) no longer regenerates on every push to
  `master`. It regenerates once a release actually lands, as its own small
  auto-merged pull request, opened from the `release` job's output rather
  than committed with a direct push. This is a deliberate simplification,
  not an accidental narrowing — "every push" was never a requirement, just
  an artifact of the old job's own trigger condition, and tying it to
  releases reads better anyway ("here's what shipped") while cutting
  needless PR churn.
- `test/release.bats` is rewritten around the new configuration; it's the
  one file this repo's coverage job actually measures, so the old
  semantic-release-shaped assertions have to go, not just the config they
  guarded.
- `README.md`'s "Releasing" section and `CONTRIBUTING.md`'s references to
  `@semantic-release/github` are updated to describe what's actually
  running.
- Once a real release-please cycle is confirmed working end to end (a
  release-please PR opens, merges on its own, and a tag/GitHub
  Release/GHCR image actually land), `RELEASE_TOKEN` is deleted as a
  repository secret. Not part of this PR — a separate, deliberate step
  after verification, per Ryan's own instruction.

## Capabilities

### New Capabilities

(none — `release` already exists as an undocumented capability; see Modified)

### Modified Capabilities

- `release`: no spec currently exists for this capability (it predates the
  OpenSpec backfill, which only covered `deploy` and `ci-coverage`). This
  change adds `openspec/specs/release/spec.md` fresh, describing the
  release-please-based behavior as the new source of truth.

## Impact

- `.releaserc.json` deleted. `release-please-config.json`,
  `.release-please-manifest.json` added.
- `package.json`: `@semantic-release/*` and `semantic-release`
  devDependencies removed; the `release` script removed (nothing local
  invokes it anymore — it's CI/action-driven only).
- `.github/workflows/ci.yml`: `release` job rewritten; new `screenshot` job
  added, gated on `needs.release.outputs.release_created`.
- `.github/workflows/release-auto-merge.yml` added.
- `test/release.bats` rewritten.
- `README.md`, `CONTRIBUTING.md` updated.
- `RELEASE_TOKEN` repository secret: deleted, but only after the new flow
  is verified working live — tracked as a follow-up, not blocking this PR.
