import { defineConfig } from "vite";
import { resolve } from "path";
import tailwindcss from "@tailwindcss/vite";
import {svelte} from "@sveltejs/vite-plugin-svelte";

export default defineConfig({
  build: {
    rollupOptions: {
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
