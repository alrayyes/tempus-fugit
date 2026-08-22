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

Merging to `master` cuts the release. [semantic-release](https://semantic-release.gitbook.io/)
reads the commits since the last tag and decides: `feat:` takes the minor, `fix:` the
patch, a `BREAKING CHANGE:` footer the major, and a branch of only `chore:` and `docs:`
releases nothing and says so. Nobody picks a version.

It writes `CHANGELOG.md`, bumps `version` in `package.json`, commits both as
`chore(release): «version» [skip ci]`, tags it and puts the notes on the Releases page.
The `[skip ci]` matters: without it that commit starts a pipeline that has nothing to
release, and the tag push starts one of its own that does.

Releasing needs no repository secret either. `@semantic-release/github` publishes with
the same automatic `GITHUB_TOKEN`, scoped to `contents: write` on the `release` job; the
same token pushes the changelog commit, since `actions/checkout` leaves it wired up as a
credential helper.

**Tags here are `v`-prefixed**, consistently, 50 out of 50, so `tagFormat` is
`v${version}` in `.releaserc.json`. That happens to be semantic-release's default, and
it is the line to read before copying this config anywhere: eight of the other
repositories tag bare, and a config carried across without changing it starts them again
at 1.0.0. There is a test on it in `test/release.bats`.

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
