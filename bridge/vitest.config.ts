import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["bridge/tests/**/*.test.ts"],
  },
});
