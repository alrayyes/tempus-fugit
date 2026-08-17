import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";

export default defineConfig({
	// No `site` here: nothing in this project reads Astro.site or generates
	// absolute URLs from it (no sitemap, no RSS), so there's nothing to set it
	// to that wouldn't just be a personal domain sitting unused in public source.
	// Kept as _site rather than Astro's dist/ so the Dockerfile, .gitignore and
	// the CI artifact path do not all have to move at the same time as the
	// generator.
	outDir: "./_site",
	build: {
		// Default is 'directory', which emits 404/index.html. Caddy rewrites to
		// /404.html, so the pages need to be files.
		format: "file",
	},
	vite: {
		plugins: [tailwindcss()],
	},
});
