#!/usr/bin/env bats
#
# scripts/assemble-reports.sh turns the artifacts the CI jobs upload into the
# site/reports/ tree that Pages serves. It runs on every pull request, so a
# broken layout fails before the merge rather than after the deploy.

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/assemble-reports.sh"

setup() {
	IN="$BATS_TEST_TMPDIR/artifacts"
	OUT="$BATS_TEST_TMPDIR/site/reports"
	mkdir -p "$IN/coverage/bats.abc" "$IN/junit-unit" "$IN/junit-smoke" "$IN/junit-e2e" \
		"$IN/playwright-report" "$IN/lighthouse"
	echo '<coverage line-rate="1"/>' >"$IN/coverage/cobertura.xml"
	echo '<html>kcov</html>' >"$IN/coverage/index.html"
	echo '{}' >"$IN/coverage/bats.abc/coverage.json"
	echo '<testsuites/>' >"$IN/junit-unit/junit.xml"
	echo '<testsuites/>' >"$IN/junit-smoke/smoke.xml"
	echo '<testsuites/>' >"$IN/junit-e2e/e2e.xml"
	echo '<html>pw</html>' >"$IN/playwright-report/index.html"
	echo '<html>lh index</html>' >"$IN/lighthouse/lhr-1.html"
	echo '{"lh":"index"}' >"$IN/lighthouse/lhr-1.json"
	echo '<html>lh other</html>' >"$IN/lighthouse/lhr-2.html"
	echo '{"lh":"other"}' >"$IN/lighthouse/lhr-2.json"
	echo '<html>skipped</html>' >"$IN/lighthouse/lhr-3.html"
	cat >"$IN/lighthouse/manifest.json" <<'JSON'
[
 {"url":"http://localhost:1/index.html","isRepresentativeRun":true,"htmlPath":"/runner/.lighthouseci/lhr-1.html","jsonPath":"/runner/.lighthouseci/lhr-1.json"},
 {"url":"http://localhost:1/404.html","isRepresentativeRun":true,"htmlPath":"/runner/.lighthouseci/lhr-2.html","jsonPath":"/runner/.lighthouseci/lhr-2.json"},
 {"url":"http://localhost:1/index.html","isRepresentativeRun":false,"htmlPath":"/runner/.lighthouseci/lhr-3.html","jsonPath":"/runner/.lighthouseci/lhr-3.json"}
]
JSON
	export GITHUB_SHA=0123456789abcdef0123456789abcdef01234567
	export REPORTS_DATE=2026-10-09
}

@test "coverage keeps the native tree and gains a Cobertura coverage.xml" {
	run "$SCRIPT" "$IN" "$OUT"
	[ "$status" -eq 0 ]
	grep -q '<coverage ' "$OUT/coverage/coverage.xml"
	[ -f "$OUT/coverage/index.html" ]
	[ -f "$OUT/coverage/bats.abc/coverage.json" ]
}

@test "tests publish one JUnit file per runner, named for it" {
	run "$SCRIPT" "$IN" "$OUT"
	[ "$status" -eq 0 ]
	for f in unit smoke e2e; do [ -f "$OUT/tests/$f.xml" ]; done
	[ -f "$OUT/tests/e2e/index.html" ]
}

@test "lighthouse publishes report.html and report.json per audited page, representative runs only" {
	run "$SCRIPT" "$IN" "$OUT"
	[ "$status" -eq 0 ]
	grep -q 'lh index' "$OUT/lighthouse/index/report.html"
	grep -q '"index"' "$OUT/lighthouse/index/report.json"
	grep -q 'lh other' "$OUT/lighthouse/404/report.html"
	run grep -rq skipped "$OUT/lighthouse"
	[ "$status" -ne 0 ]
}

@test "the index lists every report with the commit and date" {
	run "$SCRIPT" "$IN" "$OUT"
	[ "$status" -eq 0 ]
	for needle in 0123456 2026-10-09 tests/unit.xml coverage/coverage.xml lighthouse/index/report.html; do
		grep -q "$needle" "$OUT/index.html"
	done
}

@test "a missing coverage report fails the assembly" {
	rm "$IN/coverage/cobertura.xml"
	run "$SCRIPT" "$IN" "$OUT"
	[ "$status" -ne 0 ]
}
