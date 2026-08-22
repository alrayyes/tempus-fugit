#!/usr/bin/env bats
#
# Smoke tests for the built container.
#
# These deliberately test the *served artifact* rather than the generator, so
# they survive swapping out the static site generator or the web server
# underneath. Build the site first (`bun run build`) — the Dockerfile copies an
# already-built `_site`, it does not build one.
#
# Every request is made from a throwaway container on a private docker network
# rather than from a published port on localhost. Publishing a port only works
# when the daemon happens to share a network namespace with whatever is running
# the tests, which is true on a workstation and false in CI — there the daemon
# is reached over a mounted socket, so the port lands on the runner host and
# localhost sits there timing out. Talking over a docker network behaves the
# same everywhere.

CURL_IMAGE="curlimages/curl:8.19.0@sha256:c03110c736db81bbe1be0296f1f1608c81b954b01626bdfb0a8f84e5bd00ff3c"

setup_file() {
	REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

	if [ ! -f "$REPO_ROOT/_site/index.html" ]; then
		echo "_site/index.html is missing — run 'bun run build' first" >&2
		return 1
	fi

	docker build -q -t tempus-fugit:smoke "$REPO_ROOT" >/dev/null

	NETWORK="tempus-smoke-$$"
	export NETWORK
	docker network create "$NETWORK" >/dev/null

	CONTAINER="$(docker run -d --network "$NETWORK" --name "site-$$" tempus-fugit:smoke)"
	export CONTAINER
	export BASE="http://site-$$:8080"

	local i
	for i in $(seq 1 50); do
		if request -s -o /dev/null -f /; then
			return 0
		fi
		sleep 0.2
	done

	echo "container never became ready at $BASE" >&2
	docker logs "$CONTAINER" >&2
	return 1
}

teardown_file() {
	docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
	docker network rm "$NETWORK" >/dev/null 2>&1 || true
}

# request <curl args...> <path>
#
# The path is the last argument and gets $BASE prefixed onto it.
request() {
	local args=("$@")
	local last=$((${#args[@]} - 1))
	args[$last]="$BASE${args[$last]}"

	docker run --rm --network "$NETWORK" "$CURL_IMAGE" "${args[@]}"
}

status_of() {
	request -s -o /dev/null -w '%{http_code}' "$1"
}

# Strip leading ./ and ../ so a relative href from the page resolves against
# the document root the way a browser would from "/".
to_absolute() {
	local path="$1"
	while [ "${path#./}" != "$path" ] || [ "${path#../}" != "$path" ]; do
		path="${path#./}"
		path="${path#../}"
	done
	case "$path" in
	/*) printf '%s' "$path" ;;
	*) printf '/%s' "$path" ;;
	esac
}

@test "serves the landing page" {
	run request -sf /
	[ "$status" -eq 0 ]
	[[ "$output" == *"Tempus Fugit"* ]]
}

@test "the landing page ships a running timer, not just a slot for one" {
	run request -sf /
	[ "$status" -eq 0 ]
	[[ "$output" == *'id="timer"'* ]]
	# The counter is the entire point of the page, and an element with no script
	# behind it looks identical in a diff.
	[[ "$output" == *"setInterval"* ]]
}

@test "the 404 page has no timer" {
	run request -sf /404.html
	[ "$status" -eq 0 ]
	[[ "$output" != *'id="timer"'* ]]
}

@test "each page has its own title" {
	run request -sf /
	[[ "$output" == *"<title>Make it worthwhile | Tempus Fugit</title>"* ]]

	run request -sf /404.html
	[[ "$output" == *"<title>404: Not found | Tempus Fugit</title>"* ]]
}

@test "the font the page asks for actually gets generated" {
	local href
	href="$(request -sf / |
		grep -oE '<link[^>]+rel="stylesheet"[^>]*>' |
		grep -oE 'href="[^"]+"' |
		head -1 | cut -d'"' -f2)"

	[ -n "$href" ]

	run request -sf "$(to_absolute "$href")"
	[[ "$output" == *"font-home"* ]]
	[[ "$output" == *"Roboto"* ]]
}

@test "an unknown path serves the styled 404 page" {
	[ "$(status_of /no-such-page)" = "404" ]

	run request -s /no-such-page
	[[ "$output" == *"Not Found"* ]]
}

@test "every stylesheet the page links to resolves" {
	local hrefs href
	hrefs="$(request -sf / |
		grep -oE '<link[^>]+rel="stylesheet"[^>]*>' |
		grep -oE 'href="[^"]+"' |
		cut -d'"' -f2)"

	[ -n "$hrefs" ]

	for href in $hrefs; do
		[ "$(status_of "$(to_absolute "$href")")" = "200" ]
	done
}

@test "the background image and webfont resolve" {
	[ "$(status_of /images/bg.webp)" = "200" ]
	[ "$(status_of /images/bg.jpg)" = "200" ]
	[ "$(status_of /fonts/Roboto-Regular-webfont.woff)" = "200" ]
}

@test "favicons and the manifest are served from the root" {
	[ "$(status_of /favicon.ico)" = "200" ]
	[ "$(status_of /favicon-96x96.png)" = "200" ]
	[ "$(status_of /apple-touch-icon.png)" = "200" ]
	[ "$(status_of /site.webmanifest)" = "200" ]
}

# public/site.webmanifest is generator output and shipped unedited for a while —
# name "MyWebSite" — which nothing reads except a browser deciding what to call an
# installed shortcut, so it never failed visibly. Asserted here so a regenerated
# manifest can't quietly bring the placeholder name back. See #21.
@test "the manifest identifies the site, not the generator's placeholder" {
	run request -sf /site.webmanifest
	[ "$status" -eq 0 ]
	[[ "$output" == *"Tempus Fugit"* ]]
	[[ "$output" != *"MyWebSite"* ]]
	[[ "$output" != *"MySite"* ]]
}

# The page is a heading, a counter and a photograph behind them, and it used to
# arrive as 6.9 MB — a 3.2 MB favicon, an unreferenced 2.4 MB icon and a 1.4 MB
# background. Nothing about the page changed to make that happen and nothing
# about it would make it happen again visibly, so the budget is the test. See #18.
@test "no image the page pulls in blows its budget" {
	# path:bytes. The background is the one thing a visitor waits on, so it gets
	# the room; an icon a browser draws at 16 px does not.
	local budgets=(
		/images/bg.webp:262144
		/images/bg.jpg:307200
		/favicon.ico:51200
		/favicon-96x96.png:51200
		/apple-touch-icon.png:51200
		/web-app-manifest-192x192.png:51200
		/web-app-manifest-512x512.png:153600
	)

	local entry path budget size
	for entry in "${budgets[@]}"; do
		path="${entry%:*}"
		budget="${entry##*:}"

		size="$(request -sf -o /dev/null -w '%{size_download}' "$path")"
		echo "$path is $size bytes, budget $budget" >&3
		[ "$size" -gt 0 ]
		[ "$size" -le "$budget" ]
	done
}

@test "robots.txt keeps the site out of indexes" {
	run request -sf /robots.txt
	[ "$status" -eq 0 ]
	[[ "$output" == *"Disallow: /"* ]]
}

# humanstxt.org's /* TEAM */ section names whoever built the site - this is a
# single-person hobby project, not a studio crediting a client, so only the
# /* SITE */ section applies.
@test "humans.txt carries the site section but not the team" {
	run request -sf /humans.txt
	[ "$status" -eq 0 ]
	[[ "$output" == *"/* SITE */"* ]]
	[[ "$output" != *"/* TEAM */"* ]]
	[[ "$output" != *"/* THANKS */"* ]]
}

@test "the page points at humans.txt" {
	run request -sf /
	[[ "$output" == *'<link type="text/plain" rel="author" href="/humans.txt">'* ]]
}

@test "html is compressed" {
	run request -s -I -H 'Accept-Encoding: gzip, zstd' /
	[[ "$output" == *"content-encoding:"* || "$output" == *"Content-Encoding:"* ]]
}

@test "long-lived assets carry an immutable cache header" {
	run request -s -I /images/bg.jpg
	[[ "$output" == *"immutable"* ]]

	run request -s -I /fonts/Roboto-Regular-webfont.woff
	[[ "$output" == *"immutable"* ]]
}

@test "responses do not advertise the server" {
	run request -s -I /
	[[ "$output" != *"erver: "* ]]
}

@test "responses carry the basic hardening headers" {
	run request -s -I /
	[[ "$output" == *"nosniff"* ]]
	[[ "$output" == *"strict-origin-when-cross-origin"* ]]
}

@test "the server does not run as root" {
	run docker inspect --format '{{.Config.User}}' "$CONTAINER"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
	[[ "$output" != "root"* ]]
	[[ "$output" != "0"* ]]
}
