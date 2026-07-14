local completion = require("ink.completion")

local M = {}

local ErrorCodes = {
  InternalError = -32603,
  MethodNotFound = -32601,
  ServerNotInitialized = -32002,
}

local capabilities = {
  positionEncoding = "utf-16",
  textDocumentSync = {
    openClose = true,
    change = 1, -- Full. The in-process server reads the live Nvim buffer.
  },
  completionProvider = {
    resolveProvider = false,
    triggerCharacters = { ":", " ", "-", "=", "&", "@" },
  },
}

local function copy(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for key, child in pairs(value) do
    result[key] = copy(child)
  end
  return result
end

---Return the server capabilities advertised during initialize.
---@return table
function M.capabilities()
  return copy(capabilities)
end

---Handle one request without the RPC wrapper. Useful for focused tests.
---@param method string
---@param params? table
---@param initialized? boolean
---@return any result
---@return table? error
function M.handle_request(method, params, initialized)
  if method == "initialize" then
    return {
      capabilities = M.capabilities(),
      serverInfo = {
        name = "ink.nvim",
        version = "0.1.0",
      },
    }, nil
  end

  if method == "shutdown" then
    return nil, nil
  end

  if not initialized then
    return nil, {
      code = ErrorCodes.ServerNotInitialized,
      message = "Ink language server has not been initialized",
    }
  end

  if method == "textDocument/completion" then
    return completion.complete(params or {}), nil
  end

  return nil, {
    code = ErrorCodes.MethodNotFound,
    message = "Method not found: " .. tostring(method),
  }
end

local function call_on_exit(dispatchers, code, signal)
  if dispatchers and type(dispatchers.on_exit) == "function" then
    dispatchers.on_exit(code or 0, signal or 0)
  end
end

---Create Neovim's in-process `vim.lsp.rpc.PublicClient` implementation.
---@param dispatchers vim.lsp.rpc.Dispatchers
---@param _config? vim.lsp.ClientConfig
---@return vim.lsp.rpc.PublicClient
function M.new(dispatchers, _config)
  local state = {
    closing = false,
    exited = false,
    initialized = false,
    request_id = 0,
  }

  local client = {}

  local function exit_once(signal)
    state.closing = true
    if state.exited then
      return
    end
    state.exited = true
    call_on_exit(dispatchers, 0, signal or 0)
  end

  function client.request(method, params, callback, notify_reply_callback)
    if state.closing then
      return false, nil
    end

    state.request_id = state.request_id + 1
    local request_id = state.request_id
    local ok, result, response_error = pcall(
      M.handle_request,
      method,
      params,
      state.initialized
    )

    if not ok then
      response_error = {
        code = ErrorCodes.InternalError,
        message = tostring(result),
      }
      result = nil
    elseif method == "initialize" and not response_error then
      state.initialized = true
    end

    -- Match Neovim's stdio RPC ordering: a response is no longer pending
    -- before its result handler runs. Client:request() uses this callback to
    -- keep `client.requests` accurate for synchronous in-process servers.
    if type(notify_reply_callback) == "function" then
      notify_reply_callback(request_id)
    end
    if type(callback) == "function" then
      callback(response_error, result, request_id)
    end
    return true, request_id
  end

  function client.notify(method, _params)
    if state.exited then
      return false
    end
    if method == "exit" then
      exit_once(0)
    end
    -- didOpen/didChange/didClose need no mirror: completion reads the live
    -- attached buffer directly.
    return true
  end

  function client.is_closing()
    return state.closing
  end

  function client.terminate()
    exit_once(15)
  end

  return client
end

-- `cmd` is named explicitly because this function is consumed both by
-- `lsp/ink.lua` and by users who call `vim.lsp.start()` directly.
M.cmd = M.new

---Start and attach the in-process server to a buffer directly.
---Most users can instead call `vim.lsp.enable("ink")`, which loads lsp/ink.lua.
---@param opts? table `{ bufnr?: integer }` plus ClientConfig overrides
---@return integer? client_id
function M.start(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or 0
  local overrides = {}
  for key, value in pairs(opts) do
    if key ~= "bufnr" then
      overrides[key] = value
    end
  end

  local config = vim.tbl_deep_extend("force", {
    name = "ink",
    cmd = M.cmd,
    filetypes = { "ink" },
  }, overrides)
  return vim.lsp.start(config, { bufnr = bufnr })
end

M.ErrorCodes = ErrorCodes

return M
