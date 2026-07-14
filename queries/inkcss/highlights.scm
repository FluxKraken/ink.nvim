; Module shell

(comment) @comment

[
  "import"
  "from"
  "export"
  "default"
  "const"
  "function"
  "return"
  "class"
  "interface"
  "extends"
  "as"
  "new"
  "async"
] @keyword

[
  "typeof"
  "void"
] @keyword.operator

(this) @variable.builtin
(null) @constant.builtin
(boolean) @boolean
(number) @number
(string) @string
(template_string) @string

(type_identifier) @type

(const_declaration
  name: (identifier) @constant)

(function_declaration
  name: (identifier) @function)

(method_definition
  name: (identifier) @function.method)

(new_expression
  constructor: (identifier) @constructor)

(call_expression
  function: (identifier) @function.call)

(member_expression
  property: (identifier) @property)

(parameter
  pattern: (identifier) @variable.parameter)

(import_specifier
  name: (identifier) @variable)

(import_specifier
  alias: (identifier) @variable)

(export_specifier
  name: (identifier) @variable)

(export_specifier
  alias: (identifier) @variable)

(identifier) @variable

; Relaxed objects and selectors

(property_key) @property

((object_entry
  key: (property_key) @tag
  value: (object))
  (#set! priority 105))

(quoted_key) @string.special
(type_selector) @tag
(universal_selector) @tag
(attribute_selector) @attribute
(selector_condition_text) @string.special

(class_selector
  "." @punctuation.special
  (selector_identifier) @type)

(id_selector
  "#" @punctuation.special
  (selector_identifier) @type)

(pseudo_selector
  [":" "::"] @punctuation.special
  (selector_identifier) @attribute)

(at_rule_selector
  "@" @punctuation.special
  name: (selector_identifier) @keyword.directive)

(nesting_selector) @operator
(combinator) @operator

; CSS-shaped values and Ink expression escapes

(css_atom) @string.special

((css_function
  name: (css_atom) @function.call)
  (#set! priority 105))

(css_interpolation "=" @operator)
(explicit_expression "=" @operator)
(css_equals) @string.special
(css_colon) @string.special
(line_continuation) @punctuation.special

[
  "!"
  "!="
  "!=="
  "%"
  "&"
  "&&"
  "*"
  "*="
  "+"
  "+="
  "-"
  "-="
  "/"
  "/="
  "<"
  "<="
  "="
  "=="
  "==="
  "=>"
  ">"
  ">="
  "??"
  "|"
  "||"
  "~"
] @operator

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  ","
  "."
  ":"
  ";"
] @punctuation.delimiter
