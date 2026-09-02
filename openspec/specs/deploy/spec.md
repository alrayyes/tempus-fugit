# deploy Specification

## Purpose

Ships the built site to its production runtime and gives every pull request
its own disposable preview, without a human running a deploy by hand.

## Requirements

### Requirement: Production publishes a container image on push to master or a tag

Pushing to `master` or pushing a tag builds the site into a container image
and publishes it to GHCR (`ghcr.io/alrayyes/tempus-fugit`). A separate,
private deploy repo pulls that image onto the VPS; this repo's
responsibility ends at publishing it.

#### Scenario: Push to master

- **WHEN** a push lands on `master`
- **THEN** the `image` job builds the container and pushes it to GHCR
  tagged `latest`
- **AND** it also pushes a tag matching the ref name (slashes replaced with
  dashes)
- **AND** it prints the pushed image's digest so the deploy repo's pinned
  `compose.yaml` can be updated without pulling the image first

#### Scenario: Push a version tag

- **WHEN** a push lands on a ref matching `v*`
- **THEN** the `image` job builds and pushes the container tagged with that
  ref name
- **AND** it does not move the `latest` tag

#### Scenario: Publishing needs no repo secret

- **WHEN** the `image` job authenticates to GHCR
- **THEN** it uses the automatic per-run `GITHUB_TOKEN` scoped to
  `packages: write`
- **AND** no personal access token or repository secret is provisioned for
  this job

### Requirement: Pull requests get an isolated preview deploy

Every pull request gets its own scratch preview URL, deployed independently
of production and without touching `ci.yml`.

#### Scenario: Pull request opened or updated

- **WHEN** a pull request is opened or pushed to
- **THEN** Cloudflare's Workers Builds integration, connected directly to
  the repo, builds the site and deploys it to a per-PR preview URL
- **AND** production (the GHCR image and the VPS it deploys to) is
  unaffected

### Requirement: A fork or local checkout builds with analytics off

Analytics trackers are optional and only ever configured at the build that
actually ships.

#### Scenario: Build without repository variables

- **WHEN** the site is built anywhere other than the `image` job on this
  repo (a fork, a local checkout, any other CI job in this pipeline)
- **THEN** `PUBLIC_MATOMO_URL`, `PUBLIC_MATOMO_SITE_ID`,
  `PUBLIC_UMAMI_SCRIPT_URL` and `PUBLIC_UMAMI_WEBSITE_ID` are unset
- **AND** the built site ships with no tracking
