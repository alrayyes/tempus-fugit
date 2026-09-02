## 1. Config

- [x] 1.1 Add `release-please-config.json` (`release-type: node`,
      `include-component-in-tag: false`).
- [x] 1.2 Add `.release-please-manifest.json` seeded to `{".": "1.2.0"}`.
- [x] 1.3 Delete `.releaserc.json`.

## 2. Workflow

- [x] 2.1 Rewrite `ci.yml`'s `release` job: `googleapis/release-please-action`
      pinned by SHA, `release_created`/`tag_name` job outputs.
- [x] 2.2 Add `screenshot` job: `needs: [release]`, gated on
      `release_created`, builds, screenshots, opens+auto-merges a PR only
      if the file changed.
- [x] 2.3 Add `.github/workflows/release-auto-merge.yml`.

## 3. Dependencies

- [x] 3.1 Remove `@semantic-release/*` and `semantic-release` from
      `package.json` devDependencies; remove the `release` script; update
      `bun.lock`.

## 4. Tests and docs

- [x] 4.1 Rewrite `test/release.bats` against the new config shape.
- [x] 4.2 Update `README.md`'s "Releasing" section.
- [x] 4.3 Update `CONTRIBUTING.md`'s `@semantic-release/github` mention.

## 5. Verification (after merge, before touching the secret)

- [x] 5.1 Confirm a release-please PR opens on `master` after this change
      lands.
- [x] 5.2 Confirm it auto-merges once checks pass, with zero manual
      approval.
- [x] 5.3 Confirm a tag, GitHub Release, and GHCR image land from the
      merge.
- [x] 5.4 Confirm the screenshot job runs and, if the screenshot changed,
      its PR opens and auto-merges too.
- [x] 5.5 Decide whether `RELEASE_TOKEN` can be deleted.

### What verification actually found

The plan above assumed plain `GITHUB_TOKEN` would carry the whole flow.
It didn't, in two ways neither of us anticipated, both surfaced live on
this repo's first real release cycle rather than caught in review:

1. **A pull request authored by `GITHUB_TOKEN` sits at `action_required`
   with zero checks run** — not the "push doesn't trigger a new run"
   recursion guard this proposal's design.md already knew about, but a
   separate one specific to `pull_request` events. Confirmed on #38
   (release-please's own PR) and again on #46 (the screenshot job's PR,
   one release cycle later, once the release job's own fix exposed it).
   Fixed in #41 and #47: both `release-please-action`'s `token:` input
   and the screenshot job's `actions/checkout`/`gh` calls authenticate
   with `RELEASE_TOKEN`, a real user PAT, not `GITHUB_TOKEN`.
2. **A `GITHUB_TOKEN`-performed merge also suppresses the push event**
   that would otherwise fire this repo's own `on: push` trigger for the
   merge commit — so `release-auto-merge.yml`'s merge step needs
   `RELEASE_TOKEN` too, confirmed working via `alrayyes/deploy-ssh`'s
   already-proven pattern rather than found the hard way here.
3. `oven/bun`'s alpine image ships neither `gh` nor a git identity by
   default — the screenshot job's own PR-opening step failed on
   `gh: not found` (#44) the first time it actually ran, since that code
   path only exercises once a real release lands.

**`RELEASE_TOKEN` is not deleted, and shouldn't be** — it's structurally
required for a workflow to open a pull request its own repo's automation
then checks and merges unattended, confirmed independently on
`org-roam-to-obsidian`, `movie-planner`, and `deploy-ssh`. The achievable
goal was "no manual approval, ever", not "no token, ever" — the token
just needs to authenticate as something other than the workflow's own
`GITHUB_TOKEN`. `README.md`'s "Releasing" section explains why.
