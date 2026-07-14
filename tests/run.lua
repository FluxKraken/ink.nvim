local function has_label(items, label)
  for _, item in ipairs(items or {}) do
    if item.label == label then
      return true
    end
  end
  return false
end

local function run()
  local root = assert(vim.env.INK_NVIM_ROOT)
  local fixture = root .. "/tests/fixtures/styles.ink"

  vim.cmd.edit(vim.fn.fnameescape(fixture))
  local bufnr = vim.api.nvim_get_current_buf()
  assert(vim.bo[bufnr].filetype == "ink", "*.ink should resolve to the ink filetype")
  assert(vim.bo[bufnr].commentstring == "// %s", "Ink ftplugin should set commentstring")

  local parser = vim.treesitter.get_parser(bufnr, "inkcss")
  local tree = assert(parser:parse()[1])
  assert(not tree:root():has_error(), "the integration fixture should parse without errors")

  for _, query_name in ipairs({ "highlights", "indents", "folds" }) do
    assert(vim.treesitter.query.get("inkcss", query_name), query_name .. " query should load")
  end

  local highlights = assert(vim.treesitter.query.get("inkcss", "highlights"))
  local property_capture = false
  for capture_id, node in highlights:iter_captures(tree:root(), bufnr, 18, 19) do
    local start_row, start_col, end_row, end_col = node:range()
    if highlights.captures[capture_id] == "property"
      and start_row == 18
      and start_col <= 5
      and end_row == 18
      and end_col > 5
    then
      property_capture = true
      break
    end
  end
  assert(property_capture, "boxSizing should receive the property highlight capture")

  vim.api.nvim_set_hl(0, "TSKeyword", { fg = "#a277ff" })
  vim.api.nvim_set_hl(0, "TSProperty", { fg = "#f694ff" })
  vim.api.nvim_set_hl(0, "TSString", { fg = "#61ffca" })
  require("ink.highlights").apply()

  assert(vim.api.nvim_get_hl(0, { name = "@keyword.inkcss", link = true }).link == "TSKeyword",
    "legacy themes should color Ink keywords through TSKeyword")
  assert(vim.api.nvim_get_hl(0, { name = "@property.inkcss", link = true }).link == "TSProperty",
    "legacy themes should color Ink properties through TSProperty")
  assert(vim.api.nvim_get_hl(0, { name = "@string.special.inkcss", link = true }).link == "TSString",
    "legacy themes should color Ink CSS values through TSString")

  assert(vim.wait(1000, function()
    return #vim.lsp.get_clients({ bufnr = bufnr, name = "ink" }) > 0
  end), "the Ink LSP client should attach automatically")

  local client = assert(vim.lsp.get_clients({ bufnr = bufnr, name = "ink" })[1])
  assert(client.server_capabilities.completionProvider, "the Ink server should advertise completion")
  assert(vim.bo[bufnr].omnifunc == "v:lua.vim.lsp.omnifunc", "LSP completion should set omnifunc")

  local response = client:request_sync("textDocument/completion", {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = 18, character = 7 },
  }, 1000, bufnr)
  assert(response and not response.err, "the attached Ink client should answer completion requests")
  assert(has_label(response.result.items, "boxSizing"), "completion should include boxSizing")
  assert(vim.tbl_isempty(client.requests), "completed in-process requests should not remain pending")

  require("lsp_spec").run()
  print("ok: filetype, parser, queries, and LSP attachment")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end

vim.cmd("qa!")
