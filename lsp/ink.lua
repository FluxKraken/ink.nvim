return {
  name = "ink",
  cmd = require("ink.lsp").cmd,
  filetypes = { "ink" },
  root_markers = {
    "deno.json",
    "deno.jsonc",
    "package.json",
    "vite.config.ts",
    "vite.config.js",
    ".git",
  },
}
