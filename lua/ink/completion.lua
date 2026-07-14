local catalog = require("ink.catalog")

local M = {}

local CompletionItemKind = {
  Function = 3,
  Property = 10,
  Value = 12,
  Keyword = 14,
  Snippet = 15,
}

local InsertTextFormat = {
  PlainText = 1,
  Snippet = 2,
}

local selector_snippets = {
  { label = "&:hover", body = "&:hover: {\n  ${1}\n}" },
  { label = "&:focus", body = "&:focus: {\n  ${1}\n}" },
  { label = "&:focus-visible", body = "&:focus-visible: {\n  ${1}\n}" },
  { label = "&:active", body = "&:active: {\n  ${1}\n}" },
  { label = "&:disabled", body = "&:disabled: {\n  ${1}\n}" },
  { label = "@media", body = "@media (${1:width >= 48rem}): {\n  ${2}\n}" },
  { label = "@container", body = "@container ${1:name} (${2:width >= 30rem}): {\n  ${3}\n}" },
  { label = ":global", body = ":global(${1:selector}): {\n  ${2}\n}" },
}

local module_items = {
  {
    label = "export default",
    detail = "Ink default style object",
    body = "export default {\n  ${1}\n} as const",
  },
  {
    label = "export const",
    detail = "Export a named Ink value",
    body = "export const ${1:name} = ${2:value}",
  },
  {
    label = "const",
    detail = "Declare a CSS literal or expression",
    body = "const ${1:name} = ${2:value}",
  },
  {
    label = "import",
    detail = "Import an Ink dependency",
    body = "import { ${1:name} } from \"${2:module}\"",
  },
  {
    label = "interface",
    detail = "Declare an input shape",
    body = "interface ${1:Name} {\n  ${2}\n}",
  },
  {
    label = "function",
    detail = "Declare an Ink helper function",
    body = "function ${1:name}(${2}) {\n  return ${3:value}\n}",
  },
  {
    label = "new Theme",
    detail = "Create an Ink Theme",
    body = "new Theme({\n  ${1}\n})",
  },
}

local value_snippets = {
  ["var()"] = "var(${1:--token})",
  ["calc()"] = "calc(${1})",
  ["min()"] = "min(${1})",
  ["max()"] = "max(${1})",
  ["clamp()"] = "clamp(${1:min}, ${2:preferred}, ${3:max})",
  ["env()"] = "env(${1:safe-area-inset-top})",
  ["url()"] = "url(${1})",
  ["linear-gradient()"] = "linear-gradient(${1:90deg}, ${2:from}, ${3:to})",
  ["radial-gradient()"] = "radial-gradient(${1:circle}, ${2:from}, ${3:to})",
  ["conic-gradient()"] = "conic-gradient(from ${1:0deg}, ${2:from}, ${3:to})",
  ["repeat()"] = "repeat(${1:count}, ${2:track})",
  ["minmax()"] = "minmax(${1:min}, ${2:max})",
  ["fit-content()"] = "fit-content(${1})",
  ["cubic-bezier()"] = "cubic-bezier(${1:.4}, ${2:0}, ${3:.2}, ${4:1})",
  ["steps()"] = "steps(${1:count}, ${2:end})",
  ["=expression"] = "=${1:expression}",
}

local function clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end
  if value > maximum then
    return maximum
  end
  return value
end

local function is_space(byte)
  return byte == 9 or byte == 10 or byte == 13 or byte == 32
end

local function is_identifier_byte(byte)
  return byte ~= nil
    and ((byte >= 48 and byte <= 57)
      or (byte >= 65 and byte <= 90)
      or (byte >= 97 and byte <= 122)
      or byte == 45
      or byte == 95)
end

local function is_value_prefix_byte(byte)
  return is_identifier_byte(byte) or byte == 46 or byte == 61
end

local function is_selector_prefix_byte(byte)
  return is_identifier_byte(byte)
    or byte == 35 -- #
    or byte == 38 -- &
    or byte == 46 -- .
    or byte == 58 -- :
    or byte == 64 -- @
end

local function trim(value)
  local first, last = 1, #value
  while first <= last and is_space(value:byte(first)) do
    first = first + 1
  end
  while last >= first and is_space(value:byte(last)) do
    last = last - 1
  end
  return value:sub(first, last)
end

local function starts_with(value, prefix)
  if prefix == nil or prefix == "" then
    return true
  end
  return value:sub(1, #prefix):lower() == prefix:lower()
end

local function is_selector_snippet_prefix(prefix)
  for _, snippet in ipairs(selector_snippets) do
    if starts_with(snippet.label, prefix) then
      return true
    end
  end
  return false
end

---Extract the identifier-like prefix immediately before a byte column.
---This is deliberately lexical only; Tree-sitter determines the context.
---@param line string
---@param byte_col integer zero-based byte column
---@param kind? "property"|"selector"|"value"|"module"
---@return string prefix
---@return integer start_col zero-based byte column
function M.prefix_at(line, byte_col, kind)
  local col = clamp(byte_col or #line, 0, #line)
  local start_col = col
  local accepts = is_identifier_byte
  if kind == "value" then
    accepts = is_value_prefix_byte
  elseif kind == "selector" then
    accepts = is_selector_prefix_byte
  end

  while start_col > 0 and accepts(line:byte(start_col)) do
    start_col = start_col - 1
  end

  return line:sub(start_col + 1, col), start_col
end

local function first_non_space(line, limit)
  local last = math.min(limit or #line, #line)
  for index = 1, last do
    if not is_space(line:byte(index)) then
      return index
    end
  end
  return nil
end

local function identifier_between(line, first, last)
  if first > last then
    return nil
  end
  for index = first, last do
    if not is_identifier_byte(line:byte(index)) then
      return nil
    end
  end
  return line:sub(first, last)
end

-- Find a property separator on the current line. A colon only counts when the
-- text before it is a known camelCase property, so selector pseudo-colons do
-- not become value contexts. This is an incomplete-node fallback, not a
-- structural parser.
local function fallback_property_before_colon(line, byte_col)
  local limit = clamp(byte_col or #line, 0, #line)
  local first = first_non_space(line, limit)
  if not first then
    return nil
  end

  local quote = nil
  local escaped = false
  for index = first, limit do
    local byte = line:byte(index)
    if quote then
      if escaped then
        escaped = false
      elseif byte == 92 then
        escaped = true
      elseif byte == quote then
        quote = nil
      end
    elseif byte == 34 or byte == 39 or byte == 96 then
      quote = byte
    elseif byte == 58 then
      local key_end = index - 1
      while key_end >= first and is_space(line:byte(key_end)) do
        key_end = key_end - 1
      end
      local key = identifier_between(line, first, key_end)
      if key and catalog.is_property(key) then
        return key, index - 1
      end
      return nil
    end
  end
  return nil
end

local module_heads = {
  "export",
  "import",
  "const",
  "let",
  "interface",
  "type",
  "function",
  "class",
}

local function looks_like_module_head(prefix)
  if prefix == "" then
    return false
  end
  for _, head in ipairs(module_heads) do
    if starts_with(head, prefix) or starts_with(prefix, head) then
      return true
    end
  end
  return false
end

local function leading_identifier(line, first, limit)
  if not first then
    return nil
  end
  local last = first - 1
  while last + 1 <= limit and is_identifier_byte(line:byte(last + 1)) do
    last = last + 1
  end
  return identifier_between(line, first, last)
end

---Bounded context recovery for a missing/error syntax node.
---Only the current line is considered, and value context requires a known CSS
---property before the colon. Normal structural classification comes from the
---Tree-sitter implementation below.
---@param line string
---@param byte_col integer zero-based byte column
---@return table
function M.fallback_context(line, byte_col)
  local col = clamp(byte_col or #line, 0, #line)
  local property = fallback_property_before_colon(line, col)
  if property then
    local prefix, start_col = M.prefix_at(line, col, "value")
    return {
      kind = "value",
      property = property,
      prefix = prefix,
      prefix_start = start_col,
      source = "fallback",
    }
  end

  local first = first_non_space(line, col)
  local prefix, start_col = M.prefix_at(line, col, "property")
  local selector_prefix, selector_start_col = M.prefix_at(line, col, "selector")
  local head = leading_identifier(line, first, col)
  if (not first and col == 0) or (first == 1 and looks_like_module_head(head or prefix)) then
    return {
      kind = "module",
      prefix = prefix,
      prefix_start = start_col,
      source = "fallback",
    }
  end

  return {
    kind = "property",
    prefix = prefix,
    prefix_start = start_col,
    selector_prefix = selector_prefix,
    selector_prefix_start = selector_start_col,
    source = "fallback",
  }
end

local function node_field(node, name)
  if not node then
    return nil
  end
  local ok, values = pcall(node.field, node, name)
  if ok and values then
    return values[1]
  end
  return nil
end

local function node_type(node)
  if not node then
    return nil
  end
  local ok, value = pcall(node.type, node)
  return ok and value or nil
end

local function node_parent(node)
  if not node then
    return nil
  end
  local ok, value = pcall(node.parent, node)
  return ok and value or nil
end

local function nearest(node, wanted)
  while node do
    if wanted[node_type(node)] then
      return node
    end
    node = node_parent(node)
  end
  return nil
end

local function point_at_or_after(row, col, target_row, target_col)
  return row > target_row or (row == target_row and col >= target_col)
end

local function node_start(node)
  local ok, row, col = pcall(node.start, node)
  if ok then
    return row, col
  end
  return nil, nil
end

local function node_end(node)
  local ok, row, col = pcall(node.end_, node)
  if ok then
    return row, col
  end
  return nil, nil
end

local function get_node_text(node, bufnr)
  if not node or not vim or not vim.treesitter then
    return nil
  end
  local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
  if not ok or type(text) ~= "string" then
    return nil
  end
  return trim(text)
end

local function node_for_cursor(root, row, col)
  if not root then
    return nil
  end
  local ok, node
  -- LSP completion positions sit between bytes. Prefer the byte immediately
  -- before the cursor, otherwise Tree-sitter commonly returns the enclosing
  -- object at the exclusive end of a key/value node.
  if col > 0 then
    ok, node = pcall(root.named_descendant_for_range, root, row, col - 1, row, col - 1)
    if ok and node then
      return node
    end
  end
  ok, node = pcall(root.named_descendant_for_range, root, row, col, row, col)
  return ok and node or nil
end

local function colon_after_key_on_line(bufnr, key_node, row, col)
  local key_end_row, key_end_col = node_end(key_node)
  if not key_end_row or key_end_row ~= row or col <= key_end_col then
    return false
  end
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, row, row + 1, false)
  if not ok or not lines[1] then
    return false
  end
  local line = lines[1]
  local last = math.min(col, #line)
  for index = key_end_col + 1, last do
    if line:byte(index) == 58 then
      return true
    end
  end
  return false
end

---Classify a cursor from an inkcss syntax tree.
---The grammar contract used here is intentionally narrow: `object` contains
---`object_entry`, whose `key` and `value` fields contain `property_key` or
---`selector`, and `css_value`, `object`, or `explicit_expression`.
---@param root userdata|table
---@param bufnr integer
---@param row integer zero-based
---@param byte_col integer zero-based
---@param line? string
---@return table?
function M.context_from_tree(root, bufnr, row, byte_col, line)
  local node = node_for_cursor(root, row, byte_col)
  if not node then
    return nil
  end

  -- Stop at whichever structural boundary is closest. An outer selector entry
  -- wraps its nested object, but whitespace inside that object is a new key
  -- context rather than a value context for the outer selector.
  local boundary = node
  local entry, object
  while boundary do
    local boundary_type = node_type(boundary)
    if boundary_type == "object_entry" then
      entry = boundary
      break
    elseif boundary_type == "object" then
      object = boundary
      break
    end
    boundary = node_parent(boundary)
  end
  local kind, property, key_is_selector

  if entry then
    local key_node = node_field(entry, "key")
    local value_node = node_field(entry, "value")
    local value_ancestor = nearest(node, {
      css_value = true,
      explicit_expression = true,
    })

    if key_node then
      local key_text = get_node_text(key_node, bufnr)
      key_is_selector = node_type(key_node) == "selector"
      if node_type(key_node) == "property_key" or catalog.is_property(key_text) then
        property = key_text
      end
    end

    if value_ancestor then
      kind = "value"
    elseif value_node then
      local value_row, value_col = node_start(value_node)
      if value_row and point_at_or_after(row, byte_col, value_row, value_col) then
        kind = "value"
      end
    end

    if not kind and key_node and colon_after_key_on_line(bufnr, key_node, row, byte_col) then
      -- Tree-sitter can keep a missing value out of the `value` field while
      -- the user is midway through typing it. This bounded scan recovers only
      -- that incomplete entry.
      kind = "value"
    end

    kind = kind or "property"
  elseif object then
    -- Whitespace and an unfinished key between entries resolve to the nearest
    -- enclosing object. This works at every selector nesting depth.
    kind = "property"
  else
    kind = "module"
  end

  line = line or ""
  local selector_prefix, selector_start_col = M.prefix_at(line, byte_col, "selector")
  if kind == "value"
    and key_is_selector
    and property == nil
    and selector_prefix:sub(1, 2) == "&:"
    and is_selector_snippet_prefix(selector_prefix)
  then
    -- Until the selector's object separator is typed, `&:ho` is a valid
    -- recovery parse for an `&` entry with CSS value `ho`. The AST still tells
    -- us that the key is a selector; the punctuation-aware lexical prefix
    -- disambiguates the incomplete pseudo selector.
    kind = "property"
  end

  local prefix, start_col = M.prefix_at(line, byte_col, kind)
  if kind ~= "property" then
    selector_prefix, selector_start_col = nil, nil
  end
  return {
    kind = kind,
    property = property,
    prefix = prefix,
    prefix_start = start_col,
    selector_prefix = selector_prefix,
    selector_prefix_start = selector_start_col,
    source = "treesitter",
    node_type = node_type(node),
  }
end

local function tree_has_error(root)
  if not root then
    return false
  end
  local ok, value = pcall(root.has_error, root)
  return ok and value == true
end

---Return completion context for a live Neovim buffer.
---@param bufnr integer
---@param row integer zero-based
---@param byte_col integer zero-based
---@return table
function M.context_at(bufnr, row, byte_col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
  local line = lines[1] or ""
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "inkcss")
  if ok and parser then
    local parsed, trees = pcall(parser.parse, parser)
    if parsed and trees and trees[1] then
      local root = trees[1]:root()
      local context = M.context_from_tree(root, bufnr, row, byte_col, line)
      if context then
        -- Valid AST context always wins. Only let a current-line fallback
        -- refine a module result when the tree itself contains an error.
        if context.kind ~= "module" or not tree_has_error(root) then
          return context
        end
        local recovered = M.fallback_context(line, byte_col)
        if recovered.kind ~= "module" then
          return recovered
        end
        return context
      end
    end
  end
  return M.fallback_context(line, byte_col)
end

local function selector_tail(value)
  local first = 1
  while first <= #value and not is_identifier_byte(value:byte(first)) do
    first = first + 1
  end
  return value:sub(first), first - 1
end

local function property_items(prefix, selector_prefix)
  local items = {}
  for index, name in ipairs(catalog.complete_properties(prefix)) do
    items[#items + 1] = {
      label = name,
      kind = CompletionItemKind.Property,
      detail = "CSS property",
      insertText = name .. ": ${1}",
      insertTextFormat = InsertTextFormat.Snippet,
      sortText = string.format("1%04d", index),
    }
  end

  selector_prefix = selector_prefix or prefix
  local _, typed_punctuation = selector_tail(selector_prefix)
  for index, snippet in ipairs(selector_snippets) do
    if starts_with(snippet.label, selector_prefix) then
      local filter_text = selector_tail(snippet.label)
      items[#items + 1] = {
        label = snippet.label,
        kind = CompletionItemKind.Snippet,
        detail = "Nested selector or at-rule",
        filterText = filter_text,
        insertText = snippet.body:sub(typed_punctuation + 1),
        insertTextFormat = InsertTextFormat.Snippet,
        sortText = string.format("2%04d", index),
      }
    end
  end
  return items
end

local function value_items(property, prefix)
  local items = {}
  for index, value in ipairs(catalog.complete_values(property, prefix)) do
    local snippet = value_snippets[value]
    items[#items + 1] = {
      label = value,
      kind = snippet and CompletionItemKind.Function or CompletionItemKind.Value,
      detail = property and ("Value for " .. property) or "CSS value",
      insertText = snippet or value,
      insertTextFormat = snippet and InsertTextFormat.Snippet or InsertTextFormat.PlainText,
      sortText = string.format("1%04d", index),
    }
  end
  return items
end

local function top_level_items()
  local items = {}
  for index, item in ipairs(module_items) do
    items[#items + 1] = {
      label = item.label,
      kind = CompletionItemKind.Keyword,
      detail = item.detail,
      filterText = item.label,
      insertText = item.body,
      insertTextFormat = InsertTextFormat.Snippet,
      sortText = string.format("1%04d", index),
    }
  end
  return items
end

---Build LSP CompletionItems from a testable context table.
---@param context table
---@return table[]
function M.items_for_context(context)
  context = context or { kind = "module", prefix = "" }
  if context.kind == "property" then
    return property_items(context.prefix or "", context.selector_prefix)
  end
  if context.kind == "value" then
    return value_items(context.property, context.prefix or "")
  end
  return top_level_items()
end

local function buffer_for_uri(uri)
  if type(uri) ~= "string" or uri == "" then
    return vim.api.nvim_get_current_buf()
  end

  -- Prefer an already loaded buffer. `uri_to_bufnr()` can create a second
  -- buffer for an unnamed/synthetic document URI.
  local current = vim.api.nvim_get_current_buf()
  local candidates = { current }
  for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
    if candidate ~= current then
      candidates[#candidates + 1] = candidate
    end
  end
  for _, candidate in ipairs(candidates) do
    if vim.api.nvim_buf_is_valid(candidate) and vim.api.nvim_buf_is_loaded(candidate) then
      local converted, candidate_uri = pcall(vim.uri_from_bufnr, candidate)
      if converted and candidate_uri == uri then
        return candidate
      end
    end
  end

  local ok, bufnr = pcall(vim.uri_to_bufnr, uri)
  if ok and bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end
  return nil
end

---Handle an LSP `textDocument/completion` request.
---@param params table
---@param bufnr? integer Override used by tests and direct callers
---@return table CompletionList
function M.complete(params, bufnr)
  params = params or {}
  local position = params.position or {}
  bufnr = bufnr or buffer_for_uri(params.textDocument and params.textDocument.uri)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return { isIncomplete = false, items = {} }
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local row = clamp(position.line or 0, 0, math.max(line_count - 1, 0))
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local byte_col = vim.str_byteindex(line, "utf-16", position.character or 0, false)
  local context = M.context_at(bufnr, row, byte_col)

  return {
    isIncomplete = false,
    items = M.items_for_context(context),
  }
end

M.CompletionItemKind = CompletionItemKind
M.InsertTextFormat = InsertTextFormat

return M
