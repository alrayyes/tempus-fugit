# release Specification

## Purpose

Cuts a versioned release from Conventional Commits on `master` with no
human picking a version and no direct push to `master` that would need a
ruleset bypass.

## Requirements

### Requirement: Releases are proposed as a pull request, never pushed directly

The `release` job runs `release-please-action`. It never pushes directly
to `master`.

#### Scenario: New releasable commits land on master

- **WHEN** a `feat:`, `fix:`, or `BREAKING CHANGE:`-footed commit merges to
  `master`
- **THEN** the `release` job opens or updates a pull request proposing the
  next version, titled `chore(master): release ${version}`
- **AND** no direct push to `master` occurs

#### Scenario: Only docs/chore commits land

- **WHEN** every commit since the last release is `docs:` or `chore:`
- **THEN** no release pull request is opened or updated

### Requirement: Release automation authenticates as a real identity, not `GITHUB_TOKEN`

Any step that opens a pull request this repo's own automation is meant to
check and merge unattended — release-please-action, and the screenshot
job's own PR — authenticates with `RELEASE_TOKEN`, a real fine-grained
PAT, not the default `GITHUB_TOKEN`. This isn't about `master`'s ruleset
bypass list; merging a pull request was never a direct push and never
needed one. It's two separate GitHub protections found on this repo's
first real release cycle, neither anticipated up front:

- A pull request authored by `GITHUB_TOKEN` sits at `action_required`
  with zero checks run, the same wall a fork PR hits, even for a PR from
  a branch on this same repo.
- A `GITHUB_TOKEN`-performed merge suppresses the push event that would
  otherwise fire this repo's own `on: push` trigger for the merge commit.

#### Scenario: release-please opens its pull request

- **WHEN** `release-please-action` runs
- **THEN** it authenticates with `RELEASE_TOKEN`
- **AND** the resulting pull request's checks run normally, not held at
  `action_required`

#### Scenario: The screenshot job opens its pull request

- **WHEN** the `screenshot` job pushes a branch and opens a pull request
- **THEN** both the `git push` and the `gh` calls authenticate with
  `RELEASE_TOKEN`

### Requirement: The release pull request merges itself

`release-auto-merge.yml` arms auto-merge on the release-please pull
request as soon as it's opened or updated, matching the `autorelease:
pending` label release-please applies to its own pull request — not a
title string, so there's no second place a title pattern has to be kept
in sync. This repo's ruleset requires zero approving reviews, so merging
needs no bypass.

#### Scenario: Release PR opens

- **WHEN** a pull request labelled `autorelease: pending` is opened or
  synchronised
- **THEN** `gh pr merge --auto --squash` is armed on it, authenticated
  with `RELEASE_TOKEN`
- **AND** it merges on its own once the repository's required status
  checks pass, with no manual approval

### Requirement: Merging the release PR cuts the actual release

Merging the release pull request is what actually creates the tag and
the GitHub Release, not any earlier step.

#### Scenario: Release PR merges

- **WHEN** the release pull request merges into `master`
- **THEN** `release-please-action` creates a `v`-prefixed git tag and a
  GitHub Release with notes, via the GitHub API rather than a git push
- **AND** `CHANGELOG.md` at the repo root reflects the same notes

### Requirement: Tags stay v-prefixed, continuous with existing history

`release-please-config.json` sets `include-component-in-tag: false` and
`.release-please-manifest.json` seeds the current version, so the next tag
continues the existing `v`-prefixed sequence rather than restarting or
switching format.

#### Scenario: First release after adopting release-please

- **WHEN** release-please computes the next version
- **THEN** it finds the existing `v1.2.0` tag as the baseline
- **AND** the next tag is `v<next-version>`, not `tempus-fugit-v<next-version>`
  or an unprefixed version

### Requirement: The screenshot updates when a release actually ships

`.github/screenshot.jpg` regenerates once a release lands, not on every
push to `master` — tied to what actually shipped rather than every commit.

#### Scenario: A release just landed

- **WHEN** the `release` job's `release_created` output is `true`
- **THEN** the `screenshot` job builds the site and retakes the screenshot
- **AND** if the file changed, it opens a pull request with the update and
  arms auto-merge on it from the same job

#### Scenario: No release landed

- **WHEN** the `release` job's `release_created` output is not `true`
- **THEN** the `screenshot` job does not run
