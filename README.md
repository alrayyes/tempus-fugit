# Tempus Fugit

[![pipeline status][pipeline-badge]][pipelines]
[![coverage][coverage-badge]][coverage]
[![licence][licence-badge]](#licence)

[![A hero banner over a pocket watch photograph, with a running millisecond counter](.github/screenshot.jpg)](https://tempus-fugit.ryankes.eu/)

This is a landing page for a personal VPS — the page you get when you hit it
without asking for any particular service. It is two pages: a hero with a
running millisecond counter, and a 404. **[Live demo](https://tempus-fugit.ryankes.eu/)**.

It is built with [Astro](https://astro.build/), styled with Tailwind, and shipped as a
Caddy image that CI builds and a private deploy repo picks up.

## Running it

You need [bun](https://bun.sh) (see `packageManager` in `package.json`) and
[Vale](https://vale.sh) on your `PATH`. Vale is not a bun package, so it does not come
down with the rest and the git hooks call it directly.

```shell
bun install
vale sync
bun run start
```

`vale sync` fetches the Google and proselint style packages into `styles/`. They are not
committed, so run it once after cloning. Skip it and the hooks fail with
`style 'Google' does not exist on StylesPath`.

That starts Astro's dev server. To build the site the way CI does:

```shell
bun run build
```

which writes `_site/`.

## Deploying

You do not deploy this by hand. The image is `ghcr.io/alrayyes/tempus-fugit`. Pushing to
`master` or a tag builds it and publishes it: every ref gets a tag named after itself,
with any slashes turned into dashes, and `master` moves `:latest` on top of that. A
private deploy repo picks it up from there and pins the image by tag and digest.

Publishing needs no repository secret to provision. GHCR authenticates with the
automatic per-run `GITHUB_TOKEN`, scoped to `packages: write` on the `image` job — unlike
a self-hosted registry, there's no personal-access token to mint or rotate.

The job prints the pushed digest at the end, which is what `placeholder/compose.yaml`
pins alongside the tag. Nothing on the VPS moves until that file does.

The page supports analytics — [Matomo](https://matomo.org/) and
[Umami](https://umami.is/) — off by default and configured through repository
variables at build time. A fork or a local checkout builds with them unset and
ships with no tracking; see [`.env.example`](.env.example).

Pull requests also get a scratch preview URL from Cloudflare's own Workers Builds
integration, connected straight to this repo rather than run through `ci.yml`.
[`wrangler.jsonc`](wrangler.jsonc) only tells it where the built site lives; it has no
bearing on the GHCR image or what the VPS actually serves.

## Releasing

Merging to `master` proposes the release as a pull request.
[release-please](https://github.com/googleapis/release-please) reads the commits since
the last tag and decides: `feat:` takes the minor, `fix:` the patch, a
`BREAKING CHANGE:` footer the major, and a branch of only `chore:` and `docs:` proposes
nothing. Nobody picks a version.

It opens or updates a `chore(master): release «version»` pull request carrying the
`CHANGELOG.md` entry and the `package.json` version bump.
[`release-auto-merge.yml`](.github/workflows/release-auto-merge.yml) matches the
`autorelease: pending` label release-please applies to its own pull request and arms
`gh pr merge --auto --squash` on it, so it merges on its own once checks pass, no
manual approval. Merging is what actually cuts the tag and puts the notes on the
Releases page — release-please does that through the API, never a `git push`.

**Both steps need `RELEASE_TOKEN`, a real fine-grained PAT — not the automatic
`GITHUB_TOKEN`.** That wasn't the original plan; it's what verification found on this
repo's first real release cycle. Two separate GitHub protections, not one:

- A pull request authored by `GITHUB_TOKEN` sits at `action_required` with zero checks
  run, the same wall a fork PR hits, even though this PR comes from a branch on this
  repo. release-please-action's own PR-opening step needs `RELEASE_TOKEN`'s identity to
  avoid it (confirmed live on #38).
- A `GITHUB_TOKEN`-performed merge also suppresses the push event that would otherwise
  fire this workflow's own trigger for the merge commit — so the merge step itself
  needs `RELEASE_TOKEN` too, or nothing reacts to a release landing.

Neither is about `master`'s branch ruleset (bypass lists, review counts) — merging a
pull request was never a direct push and never needed a bypass. `RELEASE_TOKEN` isn't
going away: `alrayyes/deploy-ssh` hits the identical requirement, so this is a real
GitHub platform behaviour, not something wrong with this repo's own setup. What actually changed
from the old semantic-release setup: the PAT authenticates two `gh`/API calls instead
of a raw `git push`, and nothing here breaks when it needs periodic rotation the way a
broken checkout used to (#36) — a bad token just leaves the next release pull request
unopened instead of failing a required check.

**Tags here are `v`-prefixed**, consistently, 50 out of 50 from before this migration,
so `include-component-in-tag` is `false` in `release-please-config.json` — left on,
the next tag would be `tempus-fugit-v«version»` instead, since a package name to prefix
with already exists. `.release-please-manifest.json` is seeded to the version this repo
was already at, so numbering continues rather than restarting. There's a test on both in
`test/release.bats`.

The site screenshot (the banner above) regenerates once a release actually lands, as its
own small auto-merged pull request from the `screenshot` job — not on every push the way
it used to.

## Contributing

Testing, linting, hooks and the rest of the tool-by-tool detail live in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Licence

[GPL-3.0-or-later](LICENSE). It started as a landing page for one VPS, but the
surrounding tooling — the CI pipeline, the release setup, the smoke tests against a real served
artifact — is the part worth reusing.

GitHub is canonical: issues, pull requests, and releases all happen here. A
read-only mirror exists elsewhere, but it's private and nothing points at it.

[pipeline-badge]: https://github.com/alrayyes/tempus-fugit/actions/workflows/ci.yml/badge.svg
[pipelines]: https://github.com/alrayyes/tempus-fugit/actions
[coverage-badge]: https://codecov.io/gh/alrayyes/tempus-fugit/graph/badge.svg
[coverage]: https://codecov.io/gh/alrayyes/tempus-fugit
[licence-badge]: https://img.shields.io/badge/licence-GPL--3.0--or--later-blue
