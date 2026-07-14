local M = {}

local defaults = {
  treesitter = {
    enable = true,
    auto_start = true,
  },
  lsp = {
    enable = true,
  },
}

M.config = vim.deepcopy(defaults)

local function create_commands()
  vim.api.nvim_create_user_command("InkInstallParser", function()
    require("ink.treesitter").install()
  end, {
    desc = "Build and install the bundled Ink Tree-sitter parser",
    force = true,
  })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  vim.filetype.add({ extension = { ink = "ink" } })
  create_commands()
  require("ink.highlights").setup()

  if M.config.treesitter.enable then
    require("ink.treesitter").setup(M.config.treesitter)
  else
    pcall(vim.api.nvim_del_augroup_by_name, "InkNvimTreesitter")
  end

  if vim.fn.has("nvim-0.12") == 1 and vim.lsp and vim.lsp.enable then
    vim.lsp.enable("ink", M.config.lsp.enable)
  elseif M.config.lsp.enable then
    vim.notify("ink.nvim LSP completion requires Neovim 0.12 or newer", vim.log.levels.WARN)
  end
end

return M
