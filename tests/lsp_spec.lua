local M = {}

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
  end
end

local function has_label(items, label)
  for _, item in ipairs(items or {}) do
    if item.label == label then
      return true
    end
  end
  return false
end

function M.run()
  local catalog = require("ink.catalog")
  local completion = require("ink.completion")
  local lsp = require("ink.lsp")

  assert(#catalog.property_names() >= 502, "expected the checked-in standard/SVG CSS catalog")
  assert(catalog.is_property("textAlign"))
  assert(catalog.is_property("textDecoration"))
  assert(catalog.is_property("textUnderlineOffset"))

  local property_items = completion.items_for_context({
    kind = "property",
    prefix = "textU",
  })
  assert(has_label(property_items, "textUnderlineOffset"))

  assert(has_label(completion.items_for_context({
    kind = "value",
    property = "textAlign",
    prefix = "cen",
  }), "center"))
  assert(has_label(completion.items_for_context({
    kind = "value",
    property = "textDecoration",
    prefix = "und",
  }), "underline"))
  assert(has_label(completion.items_for_context({
    kind = "value",
    property = "textUnderlineOffset",
    prefix = "au",
  }), "auto"))

  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".ink")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "export default {",
    "  card: {",
    "    textAlign: cen",
    "    &:hover: {",
    "      textDecoration: und",
    "      textUnderlineOffset: au",
    "    }",
    "  }",
    "}",
  })
  vim.bo[bufnr].filetype = "ink"

  local align_context = completion.context_at(bufnr, 2, 18)
  assert_equal(align_context.kind, "value", "textAlign should be a value context")
  assert_equal(align_context.property, "textAlign")
  assert_equal(align_context.source, "treesitter")

  local nested_context = completion.context_at(bufnr, 4, 25)
  assert_equal(nested_context.kind, "value", "nested selector values should use their inner entry")
  assert_equal(nested_context.property, "textDecoration")
  assert_equal(nested_context.source, "treesitter")

  for _, selector_case in ipairs({
    { typed = "&:ho", label = "&:hover" },
    { typed = "@med", label = "@media" },
    { typed = ":glo", label = ":global" },
  }) do
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "export default {",
      "  card: {",
      "    " .. selector_case.typed,
      "  }",
      "}",
    })
    local selector_context = completion.context_at(bufnr, 2, 4 + #selector_case.typed)
    assert_equal(selector_context.kind, "property", selector_case.typed .. " should be a key context")
    assert_equal(selector_context.selector_prefix, selector_case.typed)
    assert(
      has_label(completion.items_for_context(selector_context), selector_case.label),
      selector_case.typed .. " should complete to " .. selector_case.label
    )
    for _, item in ipairs(completion.items_for_context(selector_context)) do
      if item.label == selector_case.label then
        assert_equal(item.filterText, selector_case.label:sub(1 + (#selector_case.typed - #selector_context.prefix)))
        assert(
          item.insertText:sub(1, #selector_context.prefix) == selector_context.prefix,
          "selector insertion should preserve already typed punctuation"
        )
      end
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "export default {",
    "  card: {",
    "    &:hover:",
    "  }",
    "}",
  })
  assert_equal(
    completion.context_at(bufnr, 2, 12).kind,
    "value",
    "a completed selector separator should no longer be a selector-prefix context"
  )

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "export default {",
    "  card: {",
    "    textAlign: cen",
    "    &:hover: {",
    "      textDecoration: und",
    "      textUnderlineOffset: au",
    "    }",
    "  }",
    "}",
  })

  local exited = false
  local rpc = lsp.new({
    on_exit = function()
      exited = true
    end,
  })
  local initialize_result
  local replied_request_id
  local initialize_ok, initialize_id = rpc.request("initialize", {}, function(err, result)
    assert(not err)
    initialize_result = result
  end, function(request_id)
    replied_request_id = request_id
  end)
  assert(initialize_ok)
  assert_equal(replied_request_id, initialize_id, "PublicClient should acknowledge completed requests")
  assert(initialize_result.capabilities.completionProvider)
  rpc.notify("initialized", {})

  local completion_result
  assert(rpc.request("textDocument/completion", {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = 5, character = 29 },
  }, function(err, result)
    assert(not err)
    completion_result = result
  end))
  assert(has_label(completion_result.items, "auto"), "PublicClient should return contextual values")

  rpc.terminate()
  assert(exited, "terminate should signal the LSP dispatcher")
  vim.bo[bufnr].modified = false
  vim.api.nvim_buf_delete(bufnr, { force = true })

  print("ok: in-process LSP completion")
end

return M
