## Why

OpenSpec was just adopted in this repo. `openspec/specs/` starts empty, but
the site already ships real capabilities that landed through past tickets
(#9, #14). Backfilling their specs now, rather than waiting for the next
change to touch them, means the spec tree describes what's actually running
from day one instead of only what changes from here on.

## What Changes

- Adds `deploy` and `ci-coverage` as documented capabilities, describing
  behavior that already shipped (Cloudflare Pages deploy in #9, coverage
  reporting in #14). No code changes — this change only writes specs for
  existing behavior.
- #11 (README wording) and #13 (Mattermost deploy notification) are not
  spec-worthy: #11 was a doc fix with no behavior, and #13 configured a
  Cloudflare account-level webhook with no in-repo code — nothing here for
  a spec to describe.

## Capabilities

### New Capabilities

- `deploy`: pushes to `master` or a tag build a container image and publish
  it to GHCR, which a private deploy repo picks up to run production on the
  VPS; pull requests get an isolated Cloudflare Workers Builds preview URL,
  wired outside `ci.yml`. Written to match what actually shipped, not #9's
  original Cloudflare-Pages-for-production plan — see Impact.
- `ci-coverage`: CI measures code coverage on each pull request and reports
  it visibly (job summary/badge) without gating the release on the upload
  succeeding.

### Modified Capabilities

(none)

## Impact

Docs only: adds `openspec/specs/deploy/spec.md` and
`openspec/specs/ci-coverage/spec.md`. No source, workflow, or config file
changes.

#9's own description proposed Cloudflare Pages as the production target;
what actually shipped instead is GHCR + a private VPS deploy repo for
production, with Cloudflare limited to PR previews (confirmed in #13's
investigation and in `README.md`'s "Deploying" section and
`wrangler.jsonc`'s comment). The `deploy` spec below describes that shipped
behavior, not #9's original proposal.
