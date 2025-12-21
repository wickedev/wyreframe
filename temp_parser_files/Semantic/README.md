# Semantic

Stage 3: Semantic Parser - Interprets box contents and generates AST.

## Modules

- **SemanticParser.res** - Main semantic parser
- **ParserRegistry.res** - Element parser registry with priority-based dispatch
- **AlignmentCalc.res** - Alignment calculation (left, center, right)
- **ASTBuilder.res** - AST construction
- **Elements/** - Element parsers (Button, Input, Link, Checkbox, Emphasis, Text)

## Purpose

Parses box content to recognize UI elements, calculates alignment based on
box boundaries, and builds the final Abstract Syntax Tree (AST).
