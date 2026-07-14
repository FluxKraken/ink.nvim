# ink.nvim

Neovim support for the `@kraken/ink` `.ink` style-module format.

`ink.nvim` provides:

- `*.ink` file detection with the `ink` filetype
- Tree-sitter highlighting for Ink's module shell, relaxed style objects,
  selectors, CSS properties and values, and explicit `=` expressions
- camelCase CSS property and property-specific value completion through a
  dependency-free, in-process LSP server

The Tree-sitter language is named `inkcss` internally. The distinct name avoids
colliding with the existing Tree-sitter grammar for Inkle's Ink language; files
still use the normal `ink` Neovim filetype.

## Requirements

- Neovim 0.12 or newer
- [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) from
  its `main` branch
- `tree-sitter-cli` 0.26.1 or newer and a C compiler for the one-time parser
  installation

The completion server runs inside Neovim. It does not require Node.js, a CSS
language server, or a separate background process.

## Installation with lazy.nvim

Create `~/.config/nvim/lua/plugins/ink.lua`:

```lua
return {
  "FluxKraken/ink.nvim",
  lazy = false,
  main = "ink",
  dependencies = {
    {
      "nvim-treesitter/nvim-treesitter",
      branch = "main",
      lazy = false,
      build = ":TSUpdate",
    },
  },
  opts = {},
}
```

Install the plugin and its dependency:

```vim
:Lazy sync
```

Restart Neovim, then build and install the bundled parser once:

```vim
:InkInstallParser
```

Open a `.ink` file to use Tree-sitter highlighting and LSP completion. Verify
the complete installation with:

```vim
:checkhealth ink
```

Re-run `:InkInstallParser` after a plugin update that changes the grammar.

### Older colorschemes

`ink.nvim` uses Neovim's current Tree-sitter `@capture` highlight names. If a
colorscheme defines only the older `TS*` highlight groups, the plugin detects
those groups and adds Ink-only fallback links. This preserves distinct colors
for keywords, CSS properties, selectors, and values while leaving modern
`@capture`-based themes and user `@capture.inkcss` overrides unchanged.

## Local development installation

With the reference lazy.nvim layout, create
`~/.config/nvim/lua/plugins/ink.lua`:

```lua
return {
  dir = vim.fn.expand("~/prog/ink_plugin"),
  name = "ink.nvim",
  lazy = false,
  main = "ink",
  dependencies = {
    {
      "nvim-treesitter/nvim-treesitter",
      branch = "main",
      lazy = false,
      build = ":TSUpdate",
    },
  },
  opts = {},
}
```

Then follow the parser installation and health-check steps above. Re-run
`:InkInstallParser` after changing the grammar locally.

## Configuration

The plugin calls `setup()` with these defaults:

```lua
require("ink").setup({
  treesitter = {
    enable = true,
    auto_start = true,
  },
  lsp = {
    enable = true,
  },
})
```

With lazy.nvim, place overrides in the spec's `opts` table. Set
`treesitter.enable`, `treesitter.auto_start`, or `lsp.enable` to `false` to
disable that behavior. Setup normally enables the `ink` LSP configuration with
`vim.lsp.enable("ink")`; a buffer can instead be attached directly with
`require("ink.lsp").start({ bufnr = 0 })`.

## Completion

The bundled LSP server currently completes:

- module-shell snippets for imports, constants, named and default exports,
  interfaces, functions, and `new Theme`
- camelCase CSS property names in style objects, including nested selector
  objects, plus common nested-selector and at-rule snippets
- curated property-specific values, CSS-wide values and functions, and Ink's
  `=expression` form

Completion is exposed through Neovim's normal LSP completion support, so it can
be requested with `<C-x><C-o>` or consumed by an LSP-aware completion plugin.

This first version intentionally focuses on completion. It does not provide
diagnostics, formatting, hover information, navigation, or semantic tokens. Its
CSS catalog is built in, so it does not discover project-specific theme tokens,
selectors, imports, or arbitrary JavaScript/TypeScript APIs, and its value list
is useful rather than exhaustive. Tree-sitter supplies structural completion
context; incomplete or erroneous syntax gets only bounded current-line
recovery. The grammar models Ink's documented TypeScript-shaped module subset
and common selectors, not arbitrary TypeScript/JavaScript or every modern CSS
selector.

## Development

Run the complete grammar and headless Neovim test suite from the checkout:

```sh
cd ~/prog/ink_plugin
make test
```

`make test` regenerates and tests the `inkcss` grammar, builds a temporary
parser, and runs the Neovim integration tests. `TREE_SITTER` and `NVIM` may be
overridden when testing alternate binaries. Development requires `make`; the
grammar generation uses Tree-sitter's native JavaScript runtime and does not
require Node.js.
