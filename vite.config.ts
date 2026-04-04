import { defineConfig } from "vite";
import { createInjectAliasesPlugin } from "./src/injectAliases";

export default defineConfig({
  server: {
    open: true,
  },
  plugins: [createInjectAliasesPlugin(__dirname)],
});
