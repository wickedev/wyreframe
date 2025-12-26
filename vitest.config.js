import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["src/**/*_test.mjs", "src/**/*.test.mjs", "src/**/*.test.ts"],
    globals: false,
  },
});
