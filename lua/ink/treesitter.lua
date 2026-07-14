local M = {}

local function plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
end

local function parser_config()
  return {
    install_info = {
      path = plugin_root(),
      location = "tree-sitter-inkcss",
    },
    maintainers = { "@kraken" },
    tier = 3,
  }
end

function M.register()
  vim.treesitter.language.register("inkcss", "ink")

  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if ok then
    parsers.inkcss = parser_config()
  end
end

function M.installed()
  return pcall(vim.treesitter.language.inspect, "inkcss")
end

function M.start(bufnr)
  bufnr = bufnr or 0
  if not M.installed() then
    return false, "The inkcss parser is not installed; run :InkInstallParser"
  end

  return pcall(vim.treesitter.start, bufnr, "inkcss")
end

function M.install()
  M.register()

  local ok, treesitter = pcall(require, "nvim-treesitter")
  if not ok then
    vim.notify("ink.nvim requires nvim-treesitter to install the inkcss parser", vim.log.levels.ERROR)
    return
  end

  local task = treesitter.install({ "inkcss" }, { force = true })
  if task and type(task.await) == "function" then
    task:await(function(err, success)
      vim.schedule(function()
        if err or success == false then
          local reason = err or "nvim-treesitter reported an unsuccessful install"
          vim.notify("Could not install the inkcss parser: " .. tostring(reason), vim.log.levels.ERROR)
          return
        end

        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.bo[bufnr].filetype == "ink" then
            M.start(bufnr)
          end
        end

        vim.notify("Installed the inkcss parser", vim.log.levels.INFO)
      end)
    end)
  end

  return task
end

function M.setup(opts)
  opts = opts or {}
  M.register()

  local group = vim.api.nvim_create_augroup("InkNvimTreesitter", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "TSUpdate",
    callback = M.register,
  })

  if opts.auto_start == false then
    return
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "ink",
    callback = function(args)
      M.start(args.buf)
    end,
  })
end

return M
