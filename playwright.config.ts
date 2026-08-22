import { defineConfig, devices } from "@playwright/test";

// Playwright's bundled Chromium is glibc-linked and won't launch on the
// alpine image the rest of this pipeline runs on - see rules/a11y.md. CI
// runs this straight on the ubuntu-latest host instead, same as `smoke`.
//
// No `webServer` block: astro preview daemonizes itself as of Astro 7
// rather than blocking in the foreground, which is what that option
// expects of the command it runs - scripts/e2e.sh starts and stops it
// around this suite instead.
export default defineConfig({
	testDir: "test",
	testMatch: "*.spec.ts",
	fullyParallel: true,
	forbidOnly: !!process.env.CI,
	retries: process.env.CI ? 2 : 0,
	use: {
		baseURL: "http://localhost:4322",
	},
	projects: [
		{
			name: "chromium",
			use: { ...devices["Desktop Chrome"] },
		},
	],
});
