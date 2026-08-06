import { resolve } from "node:path";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

export default defineConfig({
  build: {
    rolldownOptions: {
      input: {
        dashboard: resolve(__dirname, "app/frontend/dashboard.ts"),
        skadi: resolve(__dirname, "app/frontend/skadi.ts"),
      },
      // Don't hash filenames — Rails asset pipeline handles that
      output: {
        entryFileNames: "[name].js",
        chunkFileNames: "[name].js",
        assetFileNames: "[name][extname]",
        dir: "app/assets/builds",
      },
    },
    // Disable manifest — not needed without vite-rails
    manifest: false,
  },
  plugins: [tailwindcss(), svelte()],
});
