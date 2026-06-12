// Bindings to the parent `wyreframe` library (the ReScript ASCII parser +
// renderer at ../../..).

@module("wyreframe") external parse: string => 'ast = "parse"
@module("wyreframe") external render: 'ast => string = "render"
@module("wyreframe/parser/v2") external parseV2: string => 'parseResult = "parse"
