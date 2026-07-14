local M = {}

-- Neovim's current Tree-sitter API uses @capture names.  Some themes still
-- define only the pre-0.9 TS* groups.  When those legacy groups are present,
-- add language-specific fallback links so Ink retains the palette the theme
-- intended for syntax categories.  Modern themes are left alone because they
-- generally do not define these TS* groups, and `default = true` never
-- replaces a user's @capture.inkcss customization.
local legacy_groups = {
  comment = { "TSComment" },
  keyword = { "TSKeyword" },
  ["keyword.operator"] = { "TSKeywordOperator", "TSKeyword" },
  ["keyword.directive"] = { "TSKeyword", "TSInclude" },
  variable = { "TSVariable" },
  ["variable.builtin"] = { "TSVariableBuiltin", "TSVariable" },
  ["variable.parameter"] = { "TSParameter", "TSVariable" },
  constant = { "TSConstant" },
  ["constant.builtin"] = { "TSConstBuiltin", "TSConstant" },
  boolean = { "TSBoolean" },
  number = { "TSNumber" },
  string = { "TSString" },
  ["string.special"] = { "TSStringSpecial", "TSString" },
  type = { "TSType" },
  ["function"] = { "TSFunction" },
  ["function.method"] = { "TSMethod", "TSFunction" },
  ["function.call"] = { "TSFunction" },
  constructor = { "TSConstructor" },
  property = { "TSProperty", "TSField" },
  tag = { "TSTag" },
  attribute = { "TSAttribute", "TSTag" },
  operator = { "TSOperator" },
  ["punctuation.special"] = { "TSPunctSpecial" },
  ["punctuation.bracket"] = { "TSPunctBracket" },
  ["punctuation.delimiter"] = { "TSPunctDelimiter" },
}

local function is_defined(name)
  local ok, highlight = pcall(vim.api.nvim_get_hl, 0, { name = name, link = true })
  return ok and next(highlight) ~= nil
end

local function legacy_group(candidates)
  for _, name in ipairs(candidates) do
    if is_defined(name) then
      return name
    end
  end
end

function M.apply()
  for capture, candidates in pairs(legacy_groups) do
    local legacy = legacy_group(candidates)
    if legacy then
      vim.api.nvim_set_hl(0, "@" .. capture .. ".inkcss", {
        default = true,
        link = legacy,
      })
    end
  end
end

function M.setup()
  M.apply()

  local group = vim.api.nvim_create_augroup("InkNvimHighlights", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = M.apply,
  })
end

return M
