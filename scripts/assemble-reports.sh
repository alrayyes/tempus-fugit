#!/usr/bin/env bash
#
# Assembles the site/reports/ tree that GitHub Pages serves from what the CI
# jobs uploaded as artifacts. Usage: assemble-reports.sh <artifacts-dir> <out-dir>
#
# Runs on every pull request as well as on master, so a broken step fails
# before the merge; only the upload and the deploy are master-only.
#
# Layout (rules/published-reports.md):
#   tests/{unit,smoke,e2e}.xml  JUnit, one file per runner; tests/e2e/ is
#                               Playwright's HTML report
#   coverage/                   kcov's tree, plus coverage.xml in Cobertura
#   lighthouse/<page>/          report.html and report.json per audited page
#   index.html                  lists the above with the commit and date
set -euo pipefail

in="${1:?usage: assemble-reports.sh <artifacts-dir> <out-dir>}"
out="${2:?usage: assemble-reports.sh <artifacts-dir> <out-dir>}"
sha="${GITHUB_SHA:-$(git rev-parse HEAD)}"
date="${REPORTS_DATE:-$(date -u +%Y-%m-%d)}"

need() {
	[ -e "$1" ] || {
		echo "missing report input: $1" >&2
		exit 1
	}
}

rm -rf "$out"
mkdir -p "$out/tests" "$out/coverage" "$out/lighthouse"

need "$in/coverage/cobertura.xml"
cp -R "$in/coverage/." "$out/coverage/"
cp "$in/coverage/cobertura.xml" "$out/coverage/coverage.xml"
grep -q '<coverage ' "$out/coverage/coverage.xml"

need "$in/junit-unit/junit.xml"
cp "$in/junit-unit/junit.xml" "$out/tests/unit.xml"
need "$in/junit-smoke/smoke.xml"
cp "$in/junit-smoke/smoke.xml" "$out/tests/smoke.xml"
need "$in/junit-e2e/e2e.xml"
cp "$in/junit-e2e/e2e.xml" "$out/tests/e2e.xml"
need "$in/playwright-report/index.html"
mkdir -p "$out/tests/e2e"
cp -R "$in/playwright-report/." "$out/tests/e2e/"

need "$in/lighthouse/manifest.json"
pages=()
while IFS=$'\t' read -r url html json; do
	slug="${url#*://*/}"
	slug="${slug%.html}"
	slug="${slug//\//-}"
	[ -n "$slug" ] || slug=index
	mkdir -p "$out/lighthouse/$slug"
	cp "$in/lighthouse/$(basename "$html")" "$out/lighthouse/$slug/report.html"
	cp "$in/lighthouse/$(basename "$json")" "$out/lighthouse/$slug/report.json"
	pages+=("$slug")
done < <(jq -r '.[] | select(.isRepresentativeRun) | [.url, .htmlPath, .jsonPath] | @tsv' "$in/lighthouse/manifest.json")
[ "${#pages[@]}" -gt 0 ] || {
	echo "no representative Lighthouse runs in the manifest" >&2
	exit 1
}

{
	cat <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>tempus-fugit reports</title>
<style>
body { font: 1rem/1.5 system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; padding: 0 1rem; }
</style>
</head>
<body>
<h1>tempus-fugit reports</h1>
<p>Commit <code>${sha:0:7}</code>, ${date}.</p>
<h2>Tests</h2>
<ul>
<li><a href="tests/unit.xml">Release tests (JUnit)</a></li>
<li><a href="tests/smoke.xml">Smoke tests (JUnit)</a></li>
<li><a href="tests/e2e.xml">End-to-end tests (JUnit)</a> and its <a href="tests/e2e/">HTML report</a></li>
</ul>
<h2>Coverage</h2>
<p>Covers the release tooling under test, not the Astro site.</p>
<ul>
<li><a href="coverage/index.html">HTML view</a></li>
<li><a href="coverage/coverage.xml">coverage.xml (Cobertura)</a></li>
</ul>
<h2>Lighthouse</h2>
<p>Audits of the built site, not of the deployed page.</p>
<ul>
HTML
	for p in "${pages[@]}"; do
		echo "<li>${p}: <a href=\"lighthouse/${p}/report.html\">lighthouse/${p}/report.html</a>, <a href=\"lighthouse/${p}/report.json\">report.json</a></li>"
	done
	echo "</ul>"
	echo "</body>"
	echo "</html>"
} >"$out/index.html"
