## MODIFIED Requirements

### Requirement: Production publishes a container image on push to master or a tag

Pushing to `master` builds the site into a container image and publishes it
to GHCR (`ghcr.io/alrayyes/tempus-fugit`). A separate, private deploy repo
pulls that image onto the VPS; this repo's responsibility ends at
publishing it.

#### Scenario: Push to master

- **WHEN** a push lands on `master`
- **THEN** the `image` job builds the container and pushes it to GHCR
  tagged `latest`
- **AND** it also pushes a tag matching the ref name (slashes replaced with
  dashes)
- **AND** it prints the pushed image's digest so the deploy repo's pinned
  `compose.yaml` can be updated without pulling the image first

#### Scenario: Push a version tag

- **WHEN** `release-please-action` sets `release_created` to `true` on a
  push-to-master run
- **THEN** the `retag-release-image` job copies the manifest `image`
  already pushed as `:latest` on this same run to a tag matching the
  release's `tag_name`, via `docker buildx imagetools create` rather than
  rebuilding
- **AND** it does not move the `latest` tag
- **AND** this happens within the same workflow run that cut the release,
  never a second run triggered by the tag itself — a tag created through
  the GitHub API with `GITHUB_TOKEN` doesn't start a new workflow run, so
  nothing ever reacts to `on: push: tags: [...]` for it

#### Scenario: Publishing needs no repo secret

- **WHEN** the `image` job authenticates to GHCR
- **THEN** it uses the automatic per-run `GITHUB_TOKEN` scoped to
  `packages: write`
- **AND** no personal access token or repository secret is provisioned for
  this job
