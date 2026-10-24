## 1. Image

- [x] 1.1 Run the `e2e` job in `ghcr.io/alrayyes/ci-playwright` with `--ipc=host`.
- [x] 1.2 Remove the `setup-bun` and `playwright install` steps.

## 2. Drift check

- [x] 2.1 Add `scripts/test-playwright-image.sh`.
- [x] 2.2 Add `test/playwright-image.bats`, run by `bun run test` and the `smoke` job.

## 3. Docs

- [x] 3.1 Say in `CONTRIBUTING.md` what CI uses and what to bump with Playwright.
