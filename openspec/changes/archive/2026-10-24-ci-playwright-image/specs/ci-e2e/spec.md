## ADDED Requirements

### Requirement: The e2e job runs in a digest-pinned Playwright image matching the lock file

The `e2e` job runs in `ghcr.io/alrayyes/ci-playwright`, pinned by exact
version and `sha256` digest, with `--ipc=host`. The image tag equals the
`@playwright/test` version locked in `bun.lock`. No job downloads a browser.

#### Scenario: Image and lock file agree

- **WHEN** `scripts/test-playwright-image.sh` runs and the tag equals the
  locked `@playwright/test` version
- **THEN** it exits 0

#### Scenario: Image drifts from the lock file

- **WHEN** the tag differs from the version locked in `bun.lock`
- **THEN** the script exits non-zero and names both versions

#### Scenario: Pin without a digest

- **WHEN** the image reference has no `@sha256:` digest
- **THEN** the script exits non-zero

#### Scenario: Shared memory

- **WHEN** the container has no `options: --ipc=host`
- **THEN** the script exits non-zero

#### Scenario: Install step returns

- **WHEN** the workflow runs `playwright install`
- **THEN** the script exits non-zero

#### Scenario: The check runs where changes are made

- **WHEN** `bun run test` runs, in the pre-push hook or the `smoke` CI job
- **THEN** `test/playwright-image.bats` runs the script against the real
  workflow and lock file
