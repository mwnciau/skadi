import { defineConfig } from "vite";
import { resolve } from "path";

export default defineConfig({
  build: {
    // Don't hash filenames — Rails asset pipeline handles that
    rollupOptions: {
      input: {
        skadi: resolve(__dirname, "app/frontend/skadi.ts"),
      },
      output: {
        entryFileNames: "[name].js",
        chunkFileNames: "[name].js",
        assetFileNames: "[name][extname]",
        dir: "app/assets/builds",
      },
    },
    // Disable manifest — not needed without vite-rails
    manifest: false,
    // Don't empty the output dir to avoid clobbering other assets
    emptyOutDir: false,
  },
});
