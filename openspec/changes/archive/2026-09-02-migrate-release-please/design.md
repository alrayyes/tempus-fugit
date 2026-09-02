## Context

See proposal.md - Why. `master` is protected by a ruleset with a
`pull_request` rule and a `bypass_actors` list containing only Ryan's own
user account. semantic-release's `@semantic-release/git` plugin pushes the
changelog commit directly to `master`; only a token authenticating as that
one user can get past the ruleset to do that. `GITHUB_TOKEN` never can,
regardless of any other repo setting (review count included) — this was
confirmed live by checking `bypass_actors` directly, not assumed.

## Goals / Non-Goals

- Goal: no token that needs manual, periodic regeneration in the release
  path, ever again.
- Goal: preserve what the release actually produces today - a `v`-prefixed
  tag continuing from `v1.2.0` (50 existing tags, all `v`-prefixed;
  restarting the sequence or switching format breaks continuity for anyone
  who already has a stale tag checked out), `CHANGELOG.md` at the repo
  root, a GitHub Release with notes, and the screenshot travelling with the
  repo.
- Non-goal: matching semantic-release's changelog section headings
  exactly. release-please's own conventional-commits grouping is close
  enough; hand-tuning `changelog-sections` isn't worth the config surface
  for a cosmetic difference.
- Non-goal: npm publishing. `@semantic-release/npm` already ran with
  `npmPublish: false` - `package.json` is `private: true` and stays that
  way. release-please's `node` release-type still bumps the `version`
  field the same way, without needing that plugin at all.

## Decisions

**release-please over a hand-rolled "open a PR, wait, merge" script.**
It already exists, is Google-maintained, and does exactly this - proposing
this from scratch would just be reimplementing release-please worse.

**`release-type: node`, not `simple`.** `package.json`'s `version` field
has been meaningfully bumped by tooling since this repo existed
(semantic-release + `@semantic-release/npm`); keeping that continuity
matters more than avoiding one config field neither release-type actually
saves.

**`include-component-in-tag: false`, non-negotiable.** release-please's
default tag is `<package-name>-v<version>` for a root package once a
component name exists (and `package.json`'s `name` is `tempus-fugit`,
which counts). Left on default, the next tag would be
`tempus-fugit-v1.3.0` - it doesn't restart the version number the way
mismatching `tagFormat` would have for semantic-release, but it still
breaks the same `v`-prefix-only invariant `test/release.bats` has guarded
since #16. Verified against release-please's own manifest-releaser docs,
not assumed from the action's input list alone.

**Manifest seeded to `{".": "1.2.0"}`, not left to bootstrap.** A real git
tag `v1.2.0` already exists at that exact version; release-please finds it
by tag pattern and scans commits after it, no `bootstrap-sha` needed. This
is the documented path for adopting release-please onto an existing
versioned repo (`rules/releases.md`'s own "Initial version" section warns
about the analogous semantic-release trap - a fresh manifest computing from
zero would be the same class of mistake in the other tool).

**Auto-merge as its own workflow, gated on the release-please PR's title,
not on `release` job outputs.** Considered wiring the merge into the same
job that runs release-please-action, via job outputs across a `needs:`
edge. Rejected: a separate `pull_request`-triggered workflow is what
`dependabot-auto-merge.yml` already does here, it re-evaluates itself on
every push to the PR (not just the one moment the opening job ran), and
it's the pattern already proven working end-to-end elsewhere (confirmed via
a peer session's actual production use, not just the docs). One more
workflow file that looks like its sibling beats one more cross-job output
wire.

**`pull-request-title-pattern` set explicitly to `chore(release):
${version}`, not left as release-please's default.** The default varies
with target branch naming and isn't worth memorizing exactly to match in
the auto-merge workflow's `startsWith` check - pinning the string in config
means both sides of that match are decided in one place, this repo.

**Screenshot moves from "every push to master" to "only when a release is
actually cut", as its own auto-merged PR.** The old cadence was never a
stated requirement - it fell out of the screenshot step living inside the
same job semantic-release ran in, which itself ran on every push. Direct
commits to `master` aren't an option anymore (same ruleset problem this
whole change exists to avoid), and opening+merging a PR for every push
just to maybe update one file is real CI cost for no benefit over doing it
once per release. The screenshot job runs after `release`, gated on
`needs.release.outputs.release_created == 'true'`, builds, screenshots,
and if the file actually changed, pushes a new branch (unrestricted -
the ruleset only protects `master` itself) and opens+arms auto-merge on a
small PR directly from that same job, no separate workflow needed since
it's the only thing that ever opens a PR shaped that way.

## Risks / Trade-offs

- [The very first release-please run might not find `v1.2.0` correctly if
  the tag-matching logic differs subtly from what the docs describe] →
  Mitigated by testing this for real: the migration PR gets merged, the
  resulting release-please PR is inspected before its auto-merge lands
  anything, and `RELEASE_TOKEN` is deleted only after a full cycle (PR
  opens, merges, tag/Release/GHCR image land) is confirmed live, per
  Ryan's own instruction - not assumed from config alone.
- [A screenshot-update PR pays the full CI suite - lighthouse, e2e, smoke -
  just to update one JPEG] → Accepted. Matches how every other change
  lands here; a special-cased bypass for one file type is more surface to
  maintain than an occasional extra full CI run costs.
- [`release-please-action`'s own default changelog grouping reads slightly
  differently from semantic-release's] → Accepted, a Non-Goal above.
