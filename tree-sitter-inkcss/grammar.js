// Tree-sitter grammar for @kraken/ink `.ink` style modules.
//
// Ink deliberately combines a small TypeScript-shaped module shell with
// newline-separated, CSS-friendly objects.  This grammar keeps style objects
// and their entries explicit so editors can offer property/value completion
// without reparsing source text.

const PREC = {
  ASSIGNMENT: 1,
  LOGICAL_OR: 2,
  LOGICAL_AND: 3,
  EQUALITY: 4,
  RELATIONAL: 5,
  ADDITIVE: 6,
  MULTIPLICATIVE: 7,
  UNARY: 8,
  CALL: 9,
  MEMBER: 10,
};

module.exports = grammar({
  name: "inkcss",

  extras: ($) => [/[ \t\f\v]+/, $.comment],

  supertypes: ($) => [$._expression, $._value],

  conflicts: ($) => [
    [$.decorated_selector, $._selector_component],
    [$._object_key, $._type_selector],
    [$._reference_expression, $._expression],
  ],

  rules: {
    source_file: ($) => repeat(choice($._newline, $._module_item)),

    _module_item: ($) => choice(
      $.import_statement,
      $.export_default_declaration,
      $.export_declaration,
      $.export_clause,
      $.const_declaration,
      $.function_declaration,
      $.interface_declaration,
      $.class_declaration,
      $.expression_statement,
    ),

    // ---------------------------------------------------------------------
    // Module shell

    import_statement: ($) => seq(
      "import",
      choice(
        field("source", $.string),
        seq(
          field("clause", $.import_clause),
          "from",
          field("source", $.string),
        ),
      ),
      optional(";"),
    ),

    import_clause: ($) => choice(
      $.identifier,
      $.namespace_import,
      $.named_imports,
      seq(
        $.identifier,
        ",",
        choice($.namespace_import, $.named_imports),
      ),
    ),

    namespace_import: ($) => seq("*", "as", field("name", $.identifier)),

    named_imports: ($) => seq(
      "{",
      optional(seq(
        $.import_specifier,
        repeat(seq(",", $.import_specifier)),
        optional(","),
      )),
      "}",
    ),

    import_specifier: ($) => seq(
      field("name", $.identifier),
      optional(seq("as", field("alias", $.identifier))),
    ),

    export_default_declaration: ($) => seq(
      "export",
      "default",
      field("value", $.object),
      optional($.const_assertion),
      optional(";"),
    ),

    const_assertion: (_) => seq("as", "const"),

    export_declaration: ($) => seq(
      "export",
      choice(
        $.const_declaration,
        $.function_declaration,
        $.class_declaration,
      ),
    ),

    export_clause: ($) => seq(
      "export",
      "{",
      optional(seq(
        $.export_specifier,
        repeat(seq(",", $.export_specifier)),
        optional(","),
      )),
      "}",
      optional(seq("from", field("source", $.string))),
      optional(";"),
    ),

    export_specifier: ($) => seq(
      field("name", $.identifier),
      optional(seq("as", field("alias", $.identifier))),
    ),

    const_declaration: ($) => seq(
      "const",
      field("name", $.identifier),
      optional($.type_annotation),
      "=",
      field("value", choice($.arrow_function, $._value)),
      optional(";"),
    ),

    function_declaration: ($) => seq(
      optional("async"),
      "function",
      field("name", $.identifier),
      field("parameters", $.parameter_list),
      optional($.type_annotation),
      field("body", $.block),
    ),

    interface_declaration: ($) => seq(
      "interface",
      field("name", $.type_identifier),
      optional(seq(
        "extends",
        $.type_reference,
        repeat(seq(",", $.type_reference)),
      )),
      field("body", $.interface_body),
    ),

    interface_body: ($) => seq(
      "{",
      repeat(choice($._newline, $.property_signature)),
      "}",
    ),

    property_signature: ($) => seq(
      field("name", choice($.identifier, $.string)),
      optional("?"),
      $.type_annotation,
      optional(";"),
    ),

    class_declaration: ($) => seq(
      "class",
      field("name", $.identifier),
      optional(seq("extends", field("superclass", $._expression))),
      field("body", $.class_body),
    ),

    class_body: ($) => seq(
      "{",
      repeat(choice($._newline, $.method_definition)),
      "}",
    ),

    method_definition: ($) => seq(
      optional("async"),
      field("name", $.identifier),
      field("parameters", $.parameter_list),
      optional($.type_annotation),
      field("body", $.block),
    ),

    parameter_list: ($) => seq(
      "(",
      optional(seq(
        $.parameter,
        repeat(seq(",", $.parameter)),
        optional(","),
      )),
      ")",
    ),

    parameter: ($) => seq(
      field("pattern", choice($.identifier, $.object_pattern)),
      optional("?"),
      optional($.type_annotation),
      optional(seq("=", field("default", $._expression))),
    ),

    object_pattern: ($) => seq(
      "{",
      optional(seq(
        $.identifier,
        repeat(seq(",", $.identifier)),
        optional(","),
      )),
      "}",
    ),

    type_annotation: ($) => seq(":", field("type", $.type_expression)),

    type_expression: ($) => prec.right(seq(
      $.type_reference,
      repeat(seq(choice("|", "&"), $.type_reference)),
    )),

    type_reference: ($) => seq(
      $.type_identifier,
      optional($.type_arguments),
      repeat("[]"),
    ),

    type_arguments: ($) => seq(
      "<",
      $.type_expression,
      repeat(seq(",", $.type_expression)),
      optional(","),
      ">",
    ),

    type_identifier: (_) => /[A-Za-z_$][A-Za-z0-9_$]*/,

    // ---------------------------------------------------------------------
    // Stable style-object structure used by highlighting and completion.

    object: ($) => seq(
      "{",
      repeat($._object_separator),
      optional(seq(
        $.object_entry,
        repeat(seq(repeat1($._object_separator), $.object_entry)),
        repeat($._object_separator),
      )),
      "}",
    ),

    object_entry: ($) => choice(
      seq(
        field("key", $._object_key),
        ":",
        repeat($._newline),
        field("value", $._value),
      ),
      prec(2, seq(
        "=",
        field("key", alias($.identifier, $.property_key)),
      )),
    ),

    _object_key: ($) => choice(
      $.property_key,
      $.selector,
      $.quoted_key,
    ),

    property_key: (_) => choice(
      /[A-Za-z_$][A-Za-z0-9_$-]*/,
      /--[A-Za-z0-9_-]+/,
    ),

    quoted_key: ($) => $.string,

    selector: ($) => choice(
      $.at_rule_selector,
      $.selector_list,
      $.decorated_selector,
    ),

    selector_list: ($) => prec.left(seq(
      $._selector_sequence,
      repeat1(seq(",", $._selector_sequence)),
    )),

    decorated_selector: ($) => prec.left(choice(
      seq($._type_selector, repeat1($._selector_modifier)),
      seq(
        choice(
          $.universal_selector,
          $.class_selector,
          $.id_selector,
          $.attribute_selector,
          $.pseudo_selector,
          $.nesting_selector,
        ),
        repeat($._selector_component),
      ),
    )),

    _selector_sequence: ($) => prec.left(repeat1($._selector_component)),

    _selector_component: ($) => choice(
      $._type_selector,
      $.universal_selector,
      $.class_selector,
      $.id_selector,
      $.attribute_selector,
      $.pseudo_selector,
      $.nesting_selector,
      $.combinator,
    ),

    _selector_modifier: ($) => choice(
      $._type_selector,
      $.class_selector,
      $.id_selector,
      $.attribute_selector,
      $.pseudo_selector,
      $.nesting_selector,
      $.combinator,
    ),

    _type_selector: ($) => alias($.property_key, $.type_selector),
    universal_selector: (_) => "*",
    class_selector: ($) => seq(".", $.selector_identifier),
    id_selector: ($) => seq("#", $.selector_identifier),
    nesting_selector: (_) => "&",
    combinator: (_) => choice(">", "+", "~"),

    attribute_selector: (_) => token(seq(
      "[",
      repeat(choice(/[^\]\\\r\n]+/, /\\./)),
      "]",
    )),

    pseudo_selector: ($) => seq(
      choice(":", "::"),
      $.selector_identifier,
      optional($.selector_condition),
    ),

    at_rule_selector: ($) => seq(
      "@",
      field("name", $.selector_identifier),
      optional(field("condition", $.selector_condition)),
    ),

    selector_condition: ($) => seq(
      "(",
      repeat(choice($.selector_condition, $.selector_condition_text)),
      ")",
    ),

    selector_condition_text: (_) => /[^()\r\n]+/,
    selector_identifier: (_) => /[A-Za-z_-][A-Za-z0-9_-]*/,

    _object_separator: ($) => choice($._newline, $._separator_comma),
    _separator_comma: (_) => token(prec(2, ",")),

    // ---------------------------------------------------------------------
    // Ink values and CSS-shaped literals.

    _value: ($) => choice(
      $.object,
      $.array,
      $.new_expression,
      $.explicit_expression,
      $.string,
      $.template_string,
      $.boolean,
      $.number,
      $.css_value,
    ),

    array: ($) => seq(
      "[",
      optional(seq(
        field("element", $._value),
        repeat(seq($._separator_comma, field("element", $._value))),
        optional($._separator_comma),
      )),
      "]",
    ),

    new_expression: ($) => seq(
      "new",
      field("constructor", $.identifier),
      "(",
      field("argument", $.object),
      ")",
    ),

    explicit_expression: ($) => prec(4, seq(
      "=",
      field("expression", $._expression),
    )),

    css_value: ($) => prec.right(1, seq(
      $._css_start_component,
      repeat($._css_component),
    )),

    _css_start_component: ($) => choice(
      $.css_function,
      $.css_atom,
      $.css_colon,
    ),

    _css_component: ($) => choice(
      $.css_function,
      $.css_interpolation,
      $.line_continuation,
      $.css_atom,
      $.string,
      $.css_equals,
      $.css_colon,
      $._css_comma,
    ),

    css_function: ($) => prec(3, seq(
      field("name", $.css_atom),
      "(",
      repeat($._css_component),
      ")",
    )),

    css_interpolation: ($) => choice(
      prec(2, seq(
        "=",
        field("expression", $._reference_expression),
      )),
      seq(
        "=",
        "{",
        field("expression", $._expression),
        "}",
      ),
    ),

    _reference_expression: ($) => choice(
      $.identifier,
      $.member_expression,
      $.subscript_expression,
      $.call_expression,
    ),

    line_continuation: (_) => token(/_[ \t]*\r?\n[ \t]*/),
    css_atom: (_) => /[^\s=(){}\[\],:'"`]+/,
    css_equals: (_) => "=",
    css_colon: (_) => ":",
    _css_comma: (_) => token(prec(-1, ",")),

    // ---------------------------------------------------------------------
    // Small expression grammar for explicit escapes and typed helper code.

    arrow_function: ($) => seq(
      optional("async"),
      field("parameters", choice($.identifier, $.parameter_list)),
      "=>",
      field("body", choice($.block, $._expression)),
    ),

    block: ($) => seq(
      "{",
      repeat(choice(
        $._newline,
        $.return_statement,
        $.const_declaration,
        $.expression_statement,
      )),
      "}",
    ),

    return_statement: ($) => seq(
      "return",
      field("value", $._value),
      optional(";"),
    ),

    expression_statement: ($) => prec.right(seq(
      field("expression", $._expression),
      optional(";"),
    )),

    _expression: ($) => choice(
      $.identifier,
      $.this,
      $.number,
      $.string,
      $.template_string,
      $.boolean,
      $.null,
      $.parenthesized_expression,
      $.member_expression,
      $.subscript_expression,
      $.call_expression,
      $.unary_expression,
      $.binary_expression,
      $.assignment_expression,
      $.array_expression,
    ),

    parenthesized_expression: ($) => seq("(", $._expression, ")"),

    member_expression: ($) => prec.left(PREC.MEMBER, seq(
      field("object", $._expression),
      choice(".", "?."),
      field("property", $.identifier),
    )),

    subscript_expression: ($) => prec.left(PREC.MEMBER, seq(
      field("object", $._expression),
      optional("?"),
      "[",
      field("index", $._expression),
      "]",
    )),

    call_expression: ($) => prec.left(PREC.CALL, seq(
      field("function", $._expression),
      field("arguments", $.arguments),
    )),

    arguments: ($) => seq(
      "(",
      optional(seq(
        $._expression,
        repeat(seq(",", $._expression)),
        optional(","),
      )),
      ")",
    ),

    unary_expression: ($) => prec.right(PREC.UNARY, seq(
      field("operator", choice("!", "+", "-", "typeof", "void")),
      field("argument", $._expression),
    )),

    binary_expression: ($) => choice(
      ...[
        ["||", PREC.LOGICAL_OR],
        ["??", PREC.LOGICAL_OR],
        ["&&", PREC.LOGICAL_AND],
        ["==", PREC.EQUALITY],
        ["!=", PREC.EQUALITY],
        ["===", PREC.EQUALITY],
        ["!==", PREC.EQUALITY],
        ["<", PREC.RELATIONAL],
        ["<=", PREC.RELATIONAL],
        [">", PREC.RELATIONAL],
        [">=", PREC.RELATIONAL],
        ["+", PREC.ADDITIVE],
        ["-", PREC.ADDITIVE],
        ["*", PREC.MULTIPLICATIVE],
        ["/", PREC.MULTIPLICATIVE],
        ["%", PREC.MULTIPLICATIVE],
      ].map(([operator, precedence]) =>
        prec.left(precedence, seq(
          field("left", $._expression),
          field("operator", operator),
          field("right", $._expression),
        ))
      ),
    ),

    assignment_expression: ($) => prec.right(PREC.ASSIGNMENT, seq(
      field("left", choice(
        $.identifier,
        $.member_expression,
        $.subscript_expression,
      )),
      field("operator", choice("=", "+=", "-=", "*=", "/=")),
      field("right", $._expression),
    )),

    array_expression: ($) => seq(
      "[",
      optional(seq(
        $._expression,
        repeat(seq(",", $._expression)),
        optional(","),
      )),
      "]",
    ),

    identifier: (_) => /[A-Za-z_$][A-Za-z0-9_$]*/,
    this: (_) => "this",
    null: (_) => "null",
    boolean: (_) => choice("true", "false"),
    number: (_) => /-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/,

    string: (_) => token(choice(
      seq('"', repeat(choice(/[^"\\\r\n]+/, /\\./)), '"'),
      seq("'", repeat(choice(/[^'\\\r\n]+/, /\\./)), "'"),
    )),

    template_string: (_) => token(seq(
      "`",
      repeat(choice(/[^`\\]+/, /\\./)),
      "`",
    )),

    comment: (_) => token(choice(
      seq("//", /[^\r\n]*/),
      seq("/*", /[^*]*\*+([^/*][^*]*\*+)*/, "/"),
    )),

    _newline: (_) => /\r?\n/,
  },
});
