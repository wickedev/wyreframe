# Elements

Element parsers for recognizing UI components.

## Modules

- **ElementParser.res** - Parser interface definition
- **ButtonParser.res** - Button syntax parser ([ Text ])
- **InputParser.res** - Input field parser (#fieldname)
- **LinkParser.res** - Link parser ("Link Text")
- **CheckboxParser.res** - Checkbox parser ([x] / [ ])
- **EmphasisParser.res** - Emphasis text parser (* Text)
- **TextParser.res** - Fallback plain text parser

## Purpose

Extensible plugin-based system for parsing different element types from
wireframe content. Each parser implements the ElementParser interface
with priority, canParse(), and parse() methods.
