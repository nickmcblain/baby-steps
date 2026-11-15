import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "edge-runtime",
    include: ["convex/**/*.test.ts"],
    // convex/lib tests use node:test (see the test:convex script).
    exclude: ["convex/lib/**", "**/node_modules/**"],
    server: { deps: { inline: ["convex-test"] } },
  },
});
