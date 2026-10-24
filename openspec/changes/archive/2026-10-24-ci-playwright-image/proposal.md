## Why

The `e2e` job ran `bunx playwright install --with-deps chromium` on every run:
a browser download and apt, which can hang. The rest of the pipeline runs in
Alpine containers, and Playwright's Chromium is glibc-linked, so the job needs
its own Ubuntu image. `ghcr.io/alrayyes/ci-playwright` has the browsers baked
in, but they only work with the `@playwright/test` version the image was
built for, and a workflow can't read `bun.lock`. The version has to be kept in
step by a check.

## What Changes

- The `e2e` job runs in `ghcr.io/alrayyes/ci-playwright`, pinned by exact
  version and digest, with `--ipc=host`. The `setup-bun` and
  `playwright install` steps are gone.
- `scripts/test-playwright-image.sh` fails when the tag differs from the
  lockfile, the digest is missing, `--ipc=host` is missing, or an install
  step returns. `test/playwright-image.bats` tests it.
- Shipped in #161, issue #160.

## Capabilities

### New Capabilities

- `ci-e2e`: how the e2e job gets its browsers, and the check that keeps the
  image and the library in step.

### Modified Capabilities

(none)

## Impact

- `.github/workflows/ci.yml`, `scripts/e2e.sh`, `scripts/test-playwright-image.sh`,
  `test/playwright-image.bats`, `CONTRIBUTING.md`.
