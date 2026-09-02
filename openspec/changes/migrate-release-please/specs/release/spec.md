## Purpose

Cuts a versioned release from Conventional Commits on `master` with no
human picking a version and no credential that needs manual, periodic
regeneration.

## ADDED Requirements

### Requirement: Releases are proposed as a pull request, never pushed directly

The `release` job runs `release-please-action` authenticated with the
automatic `GITHUB_TOKEN`. It never pushes directly to `master`.

#### Scenario: New releasable commits land on master

- **WHEN** a `feat:`, `fix:`, or `BREAKING CHANGE:`-footed commit merges to
  `master`
- **THEN** the `release` job opens or updates a pull request proposing the
  next version, titled `chore(release): ${version}`
- **AND** no direct push to `master` occurs

#### Scenario: Only docs/chore commits land

- **WHEN** every commit since the last release is `docs:` or `chore:`
- **THEN** no release pull request is opened or updated

### Requirement: The release pull request merges itself

`release-auto-merge.yml` arms auto-merge on the release-please pull request
as soon as it's opened or updated, gated on its title rather than on any
job output — this repo's ruleset requires zero approving reviews, so
merging it needs no bypass.

#### Scenario: Release PR opens

- **WHEN** a pull request titled `chore(release): ${version}` is opened or
  synchronized
- **THEN** `gh pr merge --auto --squash` is armed on it
- **AND** it merges on its own once the repository's required status
  checks pass, with no manual approval

### Requirement: Merging the release PR cuts the actual release

Merging `chore(release): ${version}` is what actually creates the tag and
the GitHub Release, not any earlier step.

#### Scenario: Release PR merges

- **WHEN** a `chore(release): ${version}` pull request merges into
  `master`
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
