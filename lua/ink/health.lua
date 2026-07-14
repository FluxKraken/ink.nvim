local M = {}

function M.check()
  vim.health.start("ink.nvim")

  if vim.fn.has("nvim-0.12") == 1 then
    vim.health.ok("Neovim 0.12 or newer")
  else
    vim.health.error("Neovim 0.12 or newer is required for the in-process LSP server")
  end

  if pcall(require, "nvim-treesitter") then
    vim.health.ok("nvim-treesitter is available")
  else
    vim.health.error("nvim-treesitter is not available", {
      "Install nvim-treesitter from its main branch",
    })
  end

  local tree_sitter = vim.fn.exepath("tree-sitter")
  if tree_sitter ~= "" then
    vim.health.ok("tree-sitter-cli is available at " .. tree_sitter)
  else
    vim.health.error("tree-sitter-cli is required to build the bundled parser")
  end

  local compiler = vim.fn.exepath("cc")
  if compiler == "" then
    compiler = vim.fn.exepath("clang")
  end
  if compiler ~= "" then
    vim.health.ok("A C compiler is available at " .. compiler)
  else
    vim.health.error("A C compiler is required to build the bundled parser")
  end

  if require("ink.treesitter").installed() then
    vim.health.ok("The inkcss parser is installed")
  else
    vim.health.warn("The inkcss parser is not installed", {
      "Run :InkInstallParser",
    })
  end

  local config = vim.lsp.config and vim.lsp.config.ink
  if config then
    vim.health.ok("The Ink completion server is registered")
  else
    vim.health.warn("The Ink completion server is not registered")
  end
end

return M
