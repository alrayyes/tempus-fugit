# Contributing

This is the tools, the hooks, and the conventions the tools don't enforce on their own.
See [README.md](README.md) for what the page is and how to run it.

## Branching and review

Work lands through a pull request against `master`; nothing pushes there directly.
`lefthook`'s hooks run the same checks CI does before a commit or push is let through, so
a red pipeline after opening a PR should be rare rather than the first you hear of a
problem.

## Commit format

Commits follow [Conventional Commits](https://www.conventionalcommits.org/), enforced by
`.commitlintrc.json` — the `commit-msg` hook and the `commits` job in CI both run
`commitlint` against it.

## Hooks

`lefthook` (`lefthook.yml`) runs three:

- **`commit-msg`** — lints the commit message.
- **`pre-commit`** — auto-fixes what it can (`lint:fix`, Prettier, markdownlint), then
  builds the site and, if `Dockerfile` is staged, lints and builds the image.
- **`pre-push`** — the full read-only set: `lint`, `format:check`, `lint:md`,
  `lint:prose`, `hadolint`, and the smoke tests against a fresh build.

`bun install` wires these up automatically (`prepare` calls `lefthook install` outside
CI).

## Testing

Build the site first — see "Running it" in README — then:

```shell
bun run test
```

The tests are [bats](https://bats-core.readthedocs.io/), and they exercise the built
container over HTTP — they build the image, start it, and check what a visitor actually
receives. They deliberately do not look at `_site/` directly. This site has changed
generator and web server before, and the point of testing the served artifact is that
those swaps cannot quietly break an asset path without a test going red.

`pre-push` runs them, so you generally do not have to remember.

There is a Lighthouse gate too:

```shell
bun run test:lighthouse
```

It audits the built HTML rather than the running container, because Lighthouse's
categories are about the document — contrast, labels, deprecated APIs — and the
header-level things it would otherwise grade are covered properly by the smoke tests
against real Caddy. Best practices, accessibility and performance are all hard gates at
0.9, and all three currently sit at 0.99 or above. Performance was a warning at 0.76 until
the images came down — see the note on page weight below.

You need Chromium locally (`CHROME_PATH` if it is somewhere unusual). The `--no-sandbox`
flag in `lighthouserc.json` is there because Chrome's sandbox needs privileges no CI
container should have.

There is a coverage report too:

```shell
bun run test:coverage
```

`scripts/coverage.sh` runs `test/release.bats` under [kcov](https://github.com/SimonKagstrom/kcov)
and writes `coverage/cobertura.xml` for Codecov. It is the closest thing this repo has to
real source now that `@semantic-release/github` replaced the old
`scripts/forgejo-release.js` publish step — real bash, with a loop and a case statement,
not config or markup. `smoke.bats` stays out of it: it needs a docker socket to build and
run the served container, and the `kcov` image carries no docker binary to reach one from
inside itself.

`bats-core` turns a test file into a numbered copy under `TMPDIR` before running it,
which is the file `kcov` actually traces — the script pins `TMPDIR` under the workspace
and rewrites the numbered name back to `test/release.bats` afterwards, or Codecov reports
coverage against a temp file nobody can look up.

## Things that will catch you out

**`robots.txt` is `Disallow: /`.** That is deliberate. Do not "fix" it.

**The images carry a budget, and the smoke tests hold them to it.** A build used to be 6.9
MB, and 6.8 MB of that was three files: a `favicon.svg` that was really a 3.2 MB JPEG, the
same photograph again as `icon.jpg` with nothing pointing at it, and the background
photograph at its full `2400x3000`. It is 664 KB now, and the test named `no image the
page pulls in blows its budget` goes red if a replacement arrives at the old size. Raise a
number there for a deliberate change to the design, never to quieten a red run.

**The icon is a mark now, not the clock photograph.** The old favicon was that photograph
scaled down, which read as a brown blob in a 16-pixel tab icon — see #22.
`public/favicon.svg` is a genuine vector (two hands, a filled disc), and every other icon
in `public/` is generated from it. The 3760-pixel photograph is still in git history
rather than the tree, because nothing built needs it.
`git log --diff-filter=D -- public/images/icon.jpg` finds the commit that removed it.

**The background is served twice.** `public/images/bg.webp` is what a current browser
gets and `bg.jpg` is the fallback. `HeroBanner.astro` picks between them with `@supports`
rather than the usual two declarations of the same property, and that is deliberate: the
minifier deletes the first of a repeated declaration, fallback and all, which leaves the
built CSS carrying `image-set()` alone and older Safari with no background at all. Read
the built CSS, not the source, if you change this.

**There are two analytics trackers**, Matomo and Umami, both configured through
`PUBLIC_`-prefixed env vars (`Layout.astro`) rather than hardcoded — see
[`.env.example`](.env.example). Leave them unset locally and the site builds with
neither tracker present; production supplies the real values as GitHub Actions
repository variables, read only by the `image` job. The Matomo `<noscript>` pixel is
built from the Umami host and the Matomo site ID together, which looks like a
copy-paste slip that nobody has confirmed either way — that coupling is preserved
deliberately rather than picked one way or the other as part of moving these into env
vars.

**Tailwind v4 does not read `tailwind.config.js`.** Configuration lives in CSS via
`@theme` in `src/styles/global.css`. A JS config file will sit there looking authoritative
and do nothing — that is exactly how `font-home` came to generate no CSS at all for
however long, with the page quietly rendering in the browser default font. There is a
smoke test for it now.

**Biome cannot see inside a `.astro` template.** It parses the frontmatter and stops, so
it reports imports used only in the markup as unused. Those two rules are turned off for
`.astro` files in `biome.json`, and `astro check` — which does understand the template —
runs alongside it in `bun run lint`. If you are wondering why a lint error looks obviously
wrong, that is why.

**There are two formatters, and they do not overlap.** Biome owns everything it can
parse. Prettier gets Markdown and YAML, which Biome cannot format, and nothing else —
`bun run format` writes, `bun run format:check` reads. Do not hand it a file type Biome
already has; two tools with an opinion about the same character is a hook that fails
twice and fixes nothing.

Prettier runs on `proseWrap: "preserve"`, so it never reflows a paragraph or moves a line
break you put in deliberately. Tables are the reason it is here: it pads every cell to the
widest in the column and lines the pipes up, and nothing else in the stack does that. Do
not hand-align a table afterwards, because it will just redo them.

It runs _before_ markdownlint, in both the hook and CI. Prettier decides the layout and
markdownlint judges what Prettier produced; the other order has markdownlint fixing
something Prettier is about to overwrite. That is also why `.markdownlint-cli2.yaml`
extends `markdownlint/style/prettier`, which turns off the 23 rules that would argue with
it. `line-length` is deliberately switched back on over the top — that style drops it
because Prettier reflows prose, which on `preserve` it never does.

**The grammar check does not run in the hooks.** `lint:prose-mechanics` is CI only, and
that is deliberate: `ltex-cli-plus` is a 320 MB release that ships its own JDK, which is
more than a commit or a push should wait on. Point your editor at `ltex-ls-plus` and you
get the same engine over LSP, underlining as you type. Reaching CI is meant to be the
fallback, not the first you hear of it.

It is a hard gate, because a grammar or spelling mistake has a right answer. Two things
about that job will catch you out if you touch it. It exits **3** when it finds
something, not 1, so anything testing for a specific code passes a failing document. And
it runs on Debian rather than the alpine everything else uses, because the bundled JDK is
glibc-linked and will not start on musl.

`.ltex.json` holds the argued-with rules. `PASSIVE_VOICE` is off because passive voice is
style rather than mechanics. `OXFORD_SPELLING_Z_NOT_S` is off because this prose is
British and spells it `unoptimised`. `UPPERCASE_SENTENCE_START` is off because a sentence
continuing out of a fenced code block reads as lowercase to a tool that cannot see the
block. `PREPOSITION_VERB` is off because "after a deploy" is a noun here and LanguageTool
would rather it were a deployment. Everything else stays on. Product names go in the
dictionary, not into a disabled rule.

**Vale mostly warns, and that is the point.** `bun run lint:prose` prints style advice —
weasel words, Oxford commas, the clichés proselint knows — and passes anyway. Only the
two rules with a right answer stop you: `Vale.Spelling`, and `Vale.Terms`, which holds the
prose to the casing in the vocabulary so `gitlab` and `prettier` get flagged where
`GitLab` and `Prettier` are the accepted forms. Style advice that blocks a merge teaches
people `--no-verify`, which costs more than it catches.

Jargon and product names go in `styles/config/vocabularies/House/accept.txt`, one regex
per line, never a `<!-- vale off -->` comment scattered through the prose. Two Google
rules are off in `.vale.ini`: `EmDash`, because Google closes dashes up and this prose
spaces them, and `Will`, because half of the Releasing section in README is about things
that have not happened yet and there is no way to write that without the future tense.

Vale and LTeX split the work and do not overlap. Vale matches patterns you hand it and
will never reach LanguageTool's grammar database; LTeX is how you get at that from a
command line. They run as separate jobs, so the job name says which tier failed.
