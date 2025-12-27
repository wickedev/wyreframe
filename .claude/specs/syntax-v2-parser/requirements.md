# Wyreframe Syntax v2.3 Parser Requirements Document

## Introduction

This document defines the requirements for the Wyreframe Syntax v2.3 Parser. The Parser is responsible for analyzing ASCII wireframe syntax and converting it into structured UI elements (AST).

### Document Information

- **Version**: 1.0.0
- **Based on Spec**: Wyreframe Syntax v2.3 Specification
- **Created**: 2025-12-27
- **Status**: Draft

### Scope

The Parser handles the following:
- Block type (Scene, Component) parsing
- 9 core elements (Container, Text, Button, Link, Input, Select, Checkbox, Radio, Divider) parsing
- ID system processing
- String Literal and Emoji Shortcode processing
- Implicit layout inference
- PropPlaceholder processing

The Parser does NOT handle the following:
- DSL (Interaction DSL) parsing
- Rendering or code generation
- Styling and event handling

---

## Requirements

### Requirement 1: Block Type Parsing

**User Story:** As a developer, I want the Parser to recognize and parse @scene and @component blocks, so that I can identify the top-level structure of the wireframe.

**Reference**: Wyreframe Syntax v2.3 - Block Types section

#### Acceptance Criteria

1. WHEN Parser encounters a `@scene:` declaration THEN Parser SHALL create a Scene block object and extract the unique identifier (slug).

2. WHEN Parser encounters a `@title:` attribute THEN Parser SHALL store it as the title property of the Scene.

3. WHEN Parser encounters a `@device:` attribute THEN Parser SHALL set the device property to one of mobile, tablet, or desktop.

4. WHEN Parser encounters a `@transition:` attribute THEN Parser SHALL store it as the transition property of the Scene.

5. WHEN Parser encounters a `@component:` declaration THEN Parser SHALL create a Component block object and extract the unique identifier (slug).

6. WHEN Parser encounters a `@props:` attribute THEN Parser SHALL parse the comma-separated prop list and mark props with `?` suffix as optional.

7. IF the input does not contain a `@scene:` or `@component:` declaration THEN Parser SHALL raise an `Error: Missing block declaration - add @scene: or @component:` error.

---

### Requirement 2: Container Element Parsing

**User Story:** As a developer, I want the Parser to parse box-shaped Container syntax, so that I can understand the layout structure and nesting relationships.

**Reference**: Wyreframe Syntax v2.3 - Container section

#### Acceptance Criteria

1. WHEN Parser encounters a `+--name--+` pattern as the top border THEN Parser SHALL create a Container object and extract the name.

2. WHEN Parser encounters lines starting and ending with `|` inside a Container THEN Parser SHALL parse the content as children of the Container.

3. WHEN Parser encounters a `+--------+` pattern as the bottom border THEN Parser SHALL complete the Container parsing.

4. WHEN Parser encounters a nested Container inside a Container THEN Parser SHALL recursively parse it and add it to children.

5. IF the Container's bottom border is missing THEN Parser SHALL raise an `Error: Unclosed container - missing bottom border` error.

6. WHEN Parser encounters a Container without a name (`+----------+`) THEN Parser SHALL create a Container object with the name property set to null.

---

### Requirement 3: Container ID System

**User Story:** As a developer, I want the Parser to recognize IDs assigned to Containers, so that those elements can be referenced in DSL.

**Reference**: Wyreframe Syntax v2.3 - ID System section

#### Acceptance Criteria

1. WHEN Parser encounters `+#id+`, `+-#id-+`, or `+--#id--+` pattern THEN Parser SHALL store the ID in the Container's id property (Format 1).

2. WHEN Parser encounters a standalone `| #id |` line inside a Container THEN Parser SHALL store the ID in the Container's id property (Format 2).

3. IF Format 2 contains content other than the ID like `| #id text |` THEN Parser SHALL raise an `Error: Invalid ID format - ID line must contain only #id` error.

4. IF both Format 1 and Format 2 are used simultaneously THEN Parser SHALL prioritize Format 1's ID and treat Format 2 as plain text.

5. IF there are 2 or more `#id` patterns inside a Container THEN Parser SHALL raise an `Error: Multiple ID declarations in container` error.

6. WHEN Parser encounters a `| #id |` line in a multiline Container THEN Parser SHALL recognize the sole `#id` line as the Container ID regardless of position.

---

### Requirement 4: Text Element Parsing

**User Story:** As a developer, I want the Parser to parse plain text content, so that I can extract text elements from the UI.

**Reference**: Wyreframe Syntax v2.3 - Text section

#### Acceptance Criteria

1. WHEN Parser encounters text that doesn't match any other element pattern THEN Parser SHALL parse it as a Text element (fallback, priority 1).

2. WHEN Parser creates a Text element THEN Parser SHALL store the text content in the content property.

3. WHEN Parser needs to determine alignment THEN Parser SHALL set the align property to Left, Center, or Right based on the text position within the Container.

---

### Requirement 5: Button Element Parsing

**User Story:** As a developer, I want the Parser to parse `[ text ]` format button syntax, so that I can identify clickable action buttons.

**Reference**: Wyreframe Syntax v2.3 - Button section

#### Acceptance Criteria

1. WHEN Parser encounters a `[ text ]` pattern AND the pattern doesn't match Select, Input, or Checkbox patterns THEN Parser SHALL create a Button element (priority 70).

2. WHEN Parser creates a Button THEN Parser SHALL store the button label in the text property.

3. WHEN Parser creates a Button THEN Parser SHALL auto-generate the id property by converting the text to slug format.

4. WHEN Parser encounters a `[  ]` (2 or more spaces) pattern THEN Parser SHALL parse it as a Button.

5. WHEN Parser encounters a `[ x]` or `[x ]` (different space positions) pattern THEN Parser SHALL parse it as a Button.

---

### Requirement 6: Link Element Parsing

**User Story:** As a developer, I want the Parser to parse `< text >` format link syntax, so that I can identify navigation links.

**Reference**: Wyreframe Syntax v2.3 - Link section

#### Acceptance Criteria

1. WHEN Parser encounters a `< text >` pattern THEN Parser SHALL create a Link element (priority 60).

2. WHEN Parser creates a Link THEN Parser SHALL store the link text in the text property.

3. WHEN Parser creates a Link THEN Parser SHALL auto-generate the id property by converting the text to slug format.

---

### Requirement 7: Input Element Parsing

**User Story:** As a developer, I want the Parser to parse `[__fieldname__]` format input field syntax, so that I can identify text input elements.

**Reference**: Wyreframe Syntax v2.3 - Input section

#### Acceptance Criteria

1. WHEN Parser encounters a pattern starting with `[__` and ending with `__]` THEN Parser SHALL create an Input element (priority 90).

2. WHEN Parser parses a `[__email__]` pattern THEN Parser SHALL store `email` in the placeholder property.

3. WHEN Parser parses a `[__my__var__]` pattern THEN Parser SHALL extract the content between the first `__` and the last `__` as the placeholder.

4. WHEN Parser parses a `[____________]` (underscores only) pattern THEN Parser SHALL create an Input element with an empty placeholder.

5. IF a pattern starts with `[__text` but doesn't end with `__]` THEN Parser SHALL raise an `Error: Unclosed Input boundary - missing '__]'` error.

---

### Requirement 8: Select Element Parsing

**User Story:** As a developer, I want the Parser to parse `[v: Placeholder]` format dropdown syntax, so that I can identify select elements.

**Reference**: Wyreframe Syntax v2.3 - Select section

#### Acceptance Criteria

1. WHEN Parser encounters a pattern starting with `[v:` THEN Parser SHALL create a Select element (priority 95).

2. WHEN Parser creates a Select THEN Parser SHALL store the text after `v:` as the placeholder property.

3. WHEN Parser creates a Select THEN Parser SHALL generate the id property by converting the placeholder to slug format.

---

### Requirement 9: Checkbox Element Parsing

**User Story:** As a developer, I want the Parser to parse `[x]`, `[X]`, `[v]`, `[V]`, `[ ]` format checkbox syntax, so that I can identify checkbox elements.

**Reference**: Wyreframe Syntax v2.3 - Checkbox section

#### Acceptance Criteria

1. WHEN Parser encounters a `[x]` or `[X]` pattern (exactly 3 characters including brackets) followed by a label THEN Parser SHALL create a Checkbox element with checked=true (priority 80).

2. WHEN Parser encounters a `[v]` or `[V]` pattern (exactly 3 characters including brackets) followed by a label THEN Parser SHALL create a Checkbox element with checked=true.

3. WHEN Parser encounters a `[ ]` pattern (exactly 3 characters including brackets, 1 space) followed by a label THEN Parser SHALL create a Checkbox element with checked=false.

4. WHEN Parser creates a Checkbox THEN Parser SHALL store the text after the brackets as the label property.

5. IF no label follows the Checkbox pattern THEN Parser SHALL raise a warning indicating that a label is required.

---

### Requirement 10: Radio Element Parsing

**User Story:** As a developer, I want the Parser to parse `(*)`, `( )` format radio button syntax, so that I can identify single-select elements.

**Reference**: Wyreframe Syntax v2.3 - Radio section

#### Acceptance Criteria

1. WHEN Parser encounters a `(*)` pattern followed by a label THEN Parser SHALL create a Radio element with selected=true (priority 85).

2. WHEN Parser encounters a `( )` pattern followed by a label THEN Parser SHALL create a Radio element with selected=false.

3. WHEN Parser creates a Radio THEN Parser SHALL store the text after the parentheses as the label property.

4. WHEN Parser encounters vertically consecutive Radio buttons THEN Parser SHALL group them as the same group.

5. WHEN Parser encounters Radio buttons side by side on the same line THEN Parser SHALL group them as the same group.

6. WHEN Parser encounters Radio buttons within the same Container THEN Parser SHALL group them as the same group.

7. IF no label follows the Radio pattern THEN Parser SHALL raise a warning indicating that a label is required.

---

### Requirement 11: Divider Element Parsing

**User Story:** As a developer, I want the Parser to parse `---`, `===` format divider syntax, so that I can identify section separator elements.

**Reference**: Wyreframe Syntax v2.3 - Divider section

#### Acceptance Criteria

1. WHEN Parser encounters a `---` (1 or more dashes, 3+ recommended) pattern THEN Parser SHALL create a Divider element with style=normal (priority 40).

2. WHEN Parser encounters a `===` (1 or more equals, 3+ recommended) pattern THEN Parser SHALL create a Divider element with style=bold.

3. WHEN Parser encounters a `--- text ---` pattern AND text doesn't start with `#` THEN Parser SHALL store text in the label property (priority 48).

4. WHEN Parser encounters a `=== text ===` or `=text=` pattern AND text doesn't start with `#` THEN Parser SHALL set style=bold and store text in the label property (priority 50).

5. WHEN Parser encounters `-#id-`, `---#id---`, or `--- #id ---` pattern THEN Parser SHALL store the ID in the id property (priority 45).

6. WHEN Parser encounters `=#id=`, `===#id===` pattern THEN Parser SHALL set style=bold and store the ID in the id property.

7. IF Parser encounters a `--- text #id ---` pattern (mixed label and ID) THEN Parser SHALL raise a `Warning: Mixed label and ID in divider - treating as text` warning and treat the entire content as text.

---

### Requirement 12: String Literal Parsing

**User Story:** As a developer, I want the Parser to parse `"text"` format string literals, so that I can handle text including special characters and line breaks.

**Reference**: Wyreframe Syntax v2.3 - String Literals section

#### Acceptance Criteria

1. WHEN Parser encounters a `"text"` pattern THEN Parser SHALL create a String element and extract the inner text (priority 115).

2. WHEN Parser encounters special syntax like `< >`, `[ ]` inside a String THEN Parser SHALL treat it as plain text (disable inner parsing).

3. WHEN Parser encounters a `${prop}` pattern inside a String THEN Parser SHALL process it as PropPlaceholder interpolation.

4. WHEN Parser encounters a `\"` escape sequence THEN Parser SHALL convert it to a quote character.

5. WHEN Parser encounters a `\\` escape sequence THEN Parser SHALL convert it to a backslash character.

6. WHEN Parser encounters a `\$` escape sequence THEN Parser SHALL convert it to a dollar sign (prevent prop interpolation).

7. WHEN Parser encounters a newline character inside a String THEN Parser SHALL process it as a multiline string including the line break.

8. IF a pattern starts with `"` but has no closing `"` THEN Parser SHALL raise an `Error: Unclosed string literal - missing '"'` error.

---

### Requirement 13: Emoji Shortcode Parsing

**User Story:** As a developer, I want the Parser to parse `:name:` format emoji shortcodes, so that I can display emojis in the UI.

**Reference**: Wyreframe Syntax v2.3 - Emoji Shortcodes section

#### Acceptance Criteria

1. WHEN Parser encounters a `:name:` pattern AND name is a registered shortcode THEN Parser SHALL create an Emoji element and convert it to the corresponding emoji (priority 100).

2. WHEN Parser encounters an unknown shortcode (`:unknown:`) THEN Parser SHALL raise a `Warning: Unknown emoji shortcode ':name:' - rendering as text` warning and treat it as plain text.

3. WHEN Parser converts an emoji THEN Parser SHALL support the following shortcodes: `:check:`, `:cross:`, `:warning:`, `:info:`, `:heart:`, `:star:`, `:search:`, `:settings:`, `:user:`, `:home:`, `:mail:`, `:bell:`, `:lock:`, `:bow:`.

---

### Requirement 14: PropPlaceholder Parsing

**User Story:** As a developer, I want the Parser to parse `${prop}` format prop placeholders, so that I can handle dynamic values in components.

**Reference**: Wyreframe Syntax v2.3 - Prop Placeholder Syntax section

#### Acceptance Criteria

1. WHEN Parser encounters a `${prop}` pattern within a `@component` block THEN Parser SHALL create a PropPlaceholder element and set required=true (priority 105).

2. WHEN Parser encounters a `${prop?}` pattern within a `@component` block THEN Parser SHALL create a PropPlaceholder element and set required=false, defaultValue=null.

3. WHEN Parser encounters a `${prop:default}` pattern within a `@component` block THEN Parser SHALL create a PropPlaceholder element and store the default value in the defaultValue property.

4. IF Parser encounters a `${prop}` pattern within a `@scene` block THEN Parser SHALL raise a `Warning: PropPlaceholder outside @component - will render as literal` warning and preserve the `${prop}` text as-is.

---

### Requirement 15: Implicit Layout Detection

**User Story:** As a developer, I want the Parser to infer implicit layout based on element positions, so that I can understand the arrangement without explicit layout specification.

**Reference**: Wyreframe Syntax v2.3 - Implicit Layout Examples section

#### Acceptance Criteria

1. WHEN Parser encounters multiple elements starting on the same text line THEN Parser SHALL process those elements as horizontal arrangement (row).

2. WHEN Parser encounters multiple elements starting on different text lines THEN Parser SHALL process those elements as vertical arrangement (column).

3. WHEN Parser determines the arrangement of multiline Containers THEN Parser SHALL determine same-line status based on the Container's start line (`+--`).

4. WHEN Parser infers implicit layout THEN Parser SHALL NOT consider the spacing distance between elements for layout decisions.

---

### Requirement 16: Parsing Priority System

**User Story:** As a developer, I want the Parser to parse elements according to defined priorities, so that ambiguous patterns are interpreted correctly.

**Reference**: Wyreframe Syntax v2.3 - Parsing Rules section

#### Acceptance Criteria

1. WHEN Parser parses input THEN Parser SHALL match patterns according to the following priorities:
   - Priority 115: String (`"..."`, including multiline)
   - Priority 110: Container ID (`+--#id--+`, `| #id |`)
   - Priority 105: PropPlaceholder (`${...}`)
   - Priority 100: Emoji (`:name:`)
   - Priority 95: Select (`[v: ...]`)
   - Priority 90: Input (`[__...__]`)
   - Priority 85: Radio (`(*)`, `( )`)
   - Priority 80: Checkbox (`[x]`, `[ ]`)
   - Priority 70: Button (`[ ... ]`)
   - Priority 60: Link (`< ... >`)
   - Priority 50: Divider labeled (`=== text ===`)
   - Priority 48: Divider labeled (`--- text ---`)
   - Priority 45: Divider ID (`-#id-`)
   - Priority 40: Divider (`---`, `===`)
   - Priority 10: Container (`+--+`)
   - Priority 1: Text (fallback)

2. WHEN Parser parses bracket `[ ]` elements THEN Parser SHALL discriminate in the following order: Select > Input > Checkbox > Button.

---

### Requirement 17: Error Handling

**User Story:** As a developer, I want the Parser to clearly report syntax errors, so that I can easily identify problems when writing wireframes.

**Reference**: Wyreframe Syntax v2.3 - Error Cases section

#### Acceptance Criteria

1. WHEN Parser detects a syntax error THEN Parser SHALL create an error object containing the error message, line number, and column position.

2. WHEN Parser detects a warning THEN Parser SHALL include the warning message and position information but continue parsing.

3. WHEN Parser finds an error THEN Parser SHALL use the following error message formats:
   - `Error: Invalid ID format - ID line must contain only #id`
   - `Error: Multiple ID declarations in container`
   - `Error: Unclosed Input boundary - missing '__]'`
   - `Error: Unclosed string literal - missing '"'`
   - `Error: Unclosed container - missing bottom border`
   - `Error: Missing block declaration - add @scene: or @component:`

4. WHEN Parser finds a warning THEN Parser SHALL use the following warning message formats:
   - `Warning: PropPlaceholder outside @component - will render as literal`
   - `Warning: Unknown emoji shortcode ':name:' - rendering as text`
   - `Warning: Mixed label and ID in divider - treating as text`

---

### Requirement 18: AST (Abstract Syntax Tree) Output

**User Story:** As a developer, I want the Parser to output a structured AST, so that it can be used for subsequent processing (rendering, code generation, etc.).

#### Acceptance Criteria

1. WHEN Parser completes parsing THEN Parser SHALL return a tree-structured AST object.

2. WHEN Parser generates an AST THEN Parser SHALL include type, properties, children, and position(line, column) information in each node.

3. WHEN Parser generates an AST THEN Parser SHALL set Scene or Component as the root node.

4. WHEN Parser generates an AST THEN Parser SHALL represent nested elements as parent-child relationships.

5. WHEN Parser generates an AST THEN Parser SHALL include implicit layout information as the layout property.

---

## Non-Functional Requirements

### Requirement 19: Performance

**User Story:** As a developer, I want the Parser to operate quickly, so that it can be used without delay even in real-time editing environments.

#### Acceptance Criteria

1. WHEN Parser parses a wireframe of 100 lines or less THEN Parser SHALL complete within 50ms.

2. WHEN Parser parses a wireframe of 1000 lines or less THEN Parser SHALL complete within 500ms.

3. WHILE Parser processes a large file THEN Parser SHALL NOT exceed memory usage of 10 times the input size.

---

### Requirement 20: Extensibility

**User Story:** As a developer, I want the Parser structure to be extensible, so that new element types or syntax can be easily added.

#### Acceptance Criteria

1. WHERE the Parser's element parsing logic is implemented THEN Parser SHALL provide independent parser functions for each element type.

2. WHERE the Parser's priority system is implemented THEN Parser SHALL provide a mechanism to register new patterns.

3. WHERE the Parser's emoji shortcode mapping is implemented THEN Parser SHALL allow custom shortcodes to be registered externally.

---

### Requirement 21: Error Recovery

**User Story:** As a developer, I want the Parser to recover from partial errors, so that a single error doesn't halt the entire parsing.

#### Acceptance Criteria

1. WHEN Parser encounters an error in a specific element THEN Parser SHALL mark that element as an error node and continue parsing the next element.

2. WHEN Parser operates in error recovery mode THEN Parser SHALL collect all discovered errors and warnings and include them in the final result.

3. WHEN Parser encounters an unrecoverable error THEN Parser SHALL halt parsing with a clear error message.

---

### Requirement 22: Unicode Support

**User Story:** As a developer, I want the Parser to support Unicode characters, so that I can write multilingual wireframes.

#### Acceptance Criteria

1. WHEN Parser encounters text containing non-ASCII characters such as Korean, Japanese, or Chinese THEN Parser SHALL process those characters correctly.

2. WHEN Parser encounters text directly containing emoji characters (Unicode) THEN Parser SHALL process those characters correctly.

3. WHEN Parser calculates position information THEN Parser SHALL correctly consider Unicode characters when calculating column positions.

---

## Constraints

1. The Parser only handles ASCII wireframe syntax; DSL (Interaction DSL) is handled by a separate parser.

2. The Parser does not perform rendering or code generation.

3. The Parser is based on docs/syntax-v2.md spec version 2.3.0.

4. The output AST format of the Parser considers compatibility with subsequent processors (renderer, code generator).

---

## Assumptions

1. Input is UTF-8 encoded text.

2. Both LF (`\n`) and CRLF (`\r\n`) line endings are supported.

3. Tab characters are treated as 4 spaces.

4. Container box characters (`+`, `-`, `|`) must be in exact positions.

5. Nested Containers must be completely contained within the parent Container's boundaries.

---

## Traceability Matrix

| Requirement | Spec Section |
|-------------|--------------|
| REQ-1 Block Type | Block Types |
| REQ-2 Container | Container (Core Elements) |
| REQ-3 Container ID | ID System |
| REQ-4 Text | Text (Core Elements) |
| REQ-5 Button | Button (Core Elements) |
| REQ-6 Link | Link (Core Elements) |
| REQ-7 Input | Input (Core Elements) |
| REQ-8 Select | Select (Core Elements) |
| REQ-9 Checkbox | Checkbox (Core Elements) |
| REQ-10 Radio | Radio (Core Elements) |
| REQ-11 Divider | Divider (Core Elements) |
| REQ-12 String Literal | String Literals |
| REQ-13 Emoji | Emoji Shortcodes |
| REQ-14 PropPlaceholder | Prop Placeholder Syntax |
| REQ-15 Implicit Layout | Implicit Layout Examples |
| REQ-16 Priority | Parsing Rules |
| REQ-17 Error Handling | Error Cases |
| REQ-18 AST Output | (Implementation Detail) |
| REQ-19 Performance | (Non-functional) |
| REQ-20 Extensibility | (Non-functional) |
| REQ-21 Error Recovery | (Non-functional) |
| REQ-22 Unicode | (Non-functional) |
