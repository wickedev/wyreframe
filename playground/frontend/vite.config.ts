import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    proxy: {
      "/api": "http://localhost:8787",
    },
  },
  build: {
    sourcemap: false,
    rollupOptions: {
      // Single-bundle output like the deployed version (no code splitting).
      output: { manualChunks: undefined },
    },
  },
});
