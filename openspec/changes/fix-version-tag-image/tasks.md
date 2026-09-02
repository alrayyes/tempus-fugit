## 1. Fix

- [x] 1.1 Add `retag-release-image` job to `ci.yml`.
- [x] 1.2 Add a `test/release.bats` assertion for it.
- [x] 1.3 Correct `deploy`'s "Push a version tag" scenario via delta spec.

## 2. Verification

- [ ] 2.1 Confirm a real release actually produces a
      `ghcr.io/alrayyes/tempus-fugit:vX.Y.Z` tag, not just `:latest`.
