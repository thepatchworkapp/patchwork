import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react-swc";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "node",
    globals: true,
    include: ["convex/__tests__/**/*.test.ts"],
    exclude: ["tests/ui/**", "node_modules/**"],
  },
});
