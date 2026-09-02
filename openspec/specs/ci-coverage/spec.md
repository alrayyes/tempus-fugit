# ci-coverage Specification

## Purpose

Makes coverage over the repo's real code — `test/release.bats`, the closest
thing this static site has to application logic — visible on every pull
request, without letting a reporting-service outage take the pipeline down.

## Requirements

### Requirement: CI measures coverage on every push and pull request

`bun run test:coverage` (`scripts/coverage.sh`) runs `test/release.bats`
under `kcov` in the `coverage` CI job and writes
`coverage/cobertura.xml`.

#### Scenario: Coverage job runs

- **WHEN** the `coverage` CI job runs
- **THEN** it runs `bun run test:coverage`
- **AND** `coverage/cobertura.xml` is written with line coverage
  attributed to `test/release.bats`, not to bats-core's numbered temp copy
  of it

### Requirement: The coverage report uploads to Codecov without gating the release

Uploading is reporting, not a check — the gate is the `test:coverage` run
itself, which already ran `test/release.bats` to completion before the
upload step starts.

#### Scenario: Codecov upload succeeds

- **WHEN** `coverage/cobertura.xml` exists after `test:coverage`
- **THEN** the `coverage` job uploads it to Codecov using the
  `CODECOV_TOKEN` repository secret
- **AND** the job passes

#### Scenario: Codecov is unreachable

- **WHEN** the Codecov upload step fails (service outage, rate limit)
- **THEN** the `coverage` job still passes
- **AND** the `release` job, which depends on `coverage`, is unaffected by
  the upload failure

### Requirement: Coverage is visible without opening CI

A reader can see the current coverage level without digging into a CI run.

#### Scenario: README badge

- **WHEN** someone opens `README.md`
- **THEN** a coverage badge in the badge row links to
  `https://codecov.io/gh/alrayyes/tempus-fugit`
