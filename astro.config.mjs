import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";

export default defineConfig({
	site: "https://outpost.higherlearning.eu",
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
