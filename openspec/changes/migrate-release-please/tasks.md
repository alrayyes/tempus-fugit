## 1. Config

- [x] 1.1 Add `release-please-config.json` (`release-type: node`,
      `include-component-in-tag: false`, explicit
      `pull-request-title-pattern`).
- [x] 1.2 Add `.release-please-manifest.json` seeded to `{".": "1.2.0"}`.
- [x] 1.3 Delete `.releaserc.json`.

## 2. Workflow

- [x] 2.1 Rewrite `ci.yml`'s `release` job: `googleapis/release-please-action`
      pinned by SHA, `GITHUB_TOKEN` only, `release_created` job output.
- [x] 2.2 Add `screenshot` job: `needs: [release]`, gated on
      `release_created`, builds, screenshots, opens+auto-merges a PR only
      if the file changed.
- [x] 2.3 Add `.github/workflows/release-auto-merge.yml`, gated on the
      release-please PR's title prefix.

## 3. Dependencies

- [x] 3.1 Remove `@semantic-release/*` and `semantic-release` from
      `package.json` devDependencies; remove the `release` script; update
      `bun.lock`.

## 4. Tests and docs

- [x] 4.1 Rewrite `test/release.bats` against the new config shape.
- [x] 4.2 Update `README.md`'s "Releasing" section.
- [x] 4.3 Update `CONTRIBUTING.md`'s `@semantic-release/github` mention.

## 5. Verification (after merge, before touching the secret)

- [ ] 5.1 Confirm a release-please PR opens on `master` after this change
      lands.
- [ ] 5.2 Confirm it auto-merges once checks pass, with zero manual
      approval.
- [ ] 5.3 Confirm a tag, GitHub Release, and GHCR image land from the
      merge.
- [ ] 5.4 Confirm the screenshot job runs and, if the screenshot changed,
      its PR opens and auto-merges too.
- [ ] 5.5 Only then: delete the `RELEASE_TOKEN` repository secret.
