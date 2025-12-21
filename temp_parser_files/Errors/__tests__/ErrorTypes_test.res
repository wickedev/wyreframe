// ErrorTypes Tests
// Comprehensive tests for error type variants, severity assignment, and error creation

open ErrorTypes

// Helper function to create a test position
let makePos = (row, col) => {row: row, col: col}

describe("ErrorTypes - Severity Assignment", () => {
  test("UncloseBox has Error severity", () => {
    let code = UncloseBox({corner: makePos(1, 0), direction: "top"})
    let severity = getSeverity(code)
    assert(severity == Error)
  })

  test("MismatchedWidth has Error severity", () => {
    let code = MismatchedWidth({topLeft: makePos(1, 0), topWidth: 10, bottomWidth: 8})
    let severity = getSeverity(code)
    assert(severity == Error)
  })

  test("MisalignedPipe has Error severity", () => {
    let code = MisalignedPipe({position: makePos(2, 5), expected: 5, actual: 6})
    let severity = getSeverity(code)
    assert(severity == Error)
  })

  test("OverlappingBoxes has Error severity", () => {
    let code = OverlappingBoxes({
      box1Name: Some("Box1"),
      box2Name: Some("Box2"),
      position: makePos(3, 0),
    })
    let severity = getSeverity(code)
    assert(severity == Error)
  })

  test("InvalidElement has Error severity", () => {
    let code = InvalidElement({content: "invalid", position: makePos(5, 2)})
    let severity = getSeverity(code)
    assert(severity == Error)
  })

  test("UnclosedBracket has Error severity", () => {
    let code = UnclosedBracket({opening: makePos(4, 3)})
    let severity = getSeverity(code)
    assert(severity == Error)
  })

  test("EmptyButton has Error severity", () => {
    let code = EmptyButton({position: makePos(6, 4)})
    let severity = getSeverity(code)
    assert(severity == Error)
  })

  test("InvalidInteractionDSL has Error severity", () => {
    let code = InvalidInteractionDSL({message: "Parse failed", position: Some(makePos(7, 0))})
    let severity = getSeverity(code)
    assert(severity == Error)
  })

  test("UnusualSpacing has Warning severity", () => {
    let code = UnusualSpacing({position: makePos(8, 0), issue: "Tab character detected"})
    let severity = getSeverity(code)
    assert(severity == Warning)
  })

  test("DeepNesting has Warning severity", () => {
    let code = DeepNesting({depth: 5, position: makePos(10, 2)})
    let severity = getSeverity(code)
    assert(severity == Warning)
  })
})

describe("ErrorTypes - Error Creation", () => {
  test("make creates ParseError with correct severity", () => {
    let code = UncloseBox({corner: makePos(1, 0), direction: "right"})
    let error = make(code)

    assert(error.code == code)
    assert(error.severity == Error)
    assert(error.context == None)
  })

  test("make with context includes context data", () => {
    let code = EmptyButton({position: makePos(5, 2)})
    let context = {
      codeSnippet: Some("[ ]"),
      linesBefore: 2,
      linesAfter: 2,
    }
    let error = make(code, ~context=Some(context))

    assert(error.code == code)
    assert(error.context != None)
  })

  test("makeSimple creates ParseError without context", () => {
    let code = InvalidElement({content: "???", position: makePos(3, 1)})
    let error = makeSimple(code)

    assert(error.context == None)
  })
})

describe("ErrorTypes - Position Extraction", () => {
  test("getPosition extracts position from UncloseBox", () => {
    let pos = makePos(1, 0)
    let code = UncloseBox({corner: pos, direction: "top"})

    switch getPosition(code) {
    | Some(p) => assert(p.row == 1 && p.col == 0)
    | None => assert(false) // Should have a position
    }
  })

  test("getPosition extracts position from MismatchedWidth", () => {
    let pos = makePos(2, 3)
    let code = MismatchedWidth({topLeft: pos, topWidth: 10, bottomWidth: 8})

    switch getPosition(code) {
    | Some(p) => assert(p.row == 2 && p.col == 3)
    | None => assert(false)
    }
  })

  test("getPosition extracts position from MisalignedPipe", () => {
    let pos = makePos(4, 5)
    let code = MisalignedPipe({position: pos, expected: 5, actual: 6})

    switch getPosition(code) {
    | Some(p) => assert(p.row == 4 && p.col == 5)
    | None => assert(false)
    }
  })

  test("getPosition handles InvalidInteractionDSL with no position", () => {
    let code = InvalidInteractionDSL({message: "Parse error", position: None})

    switch getPosition(code) {
    | Some(_) => assert(false) // Should be None
    | None => assert(true)
    }
  })

  test("getPosition handles InvalidInteractionDSL with position", () => {
    let pos = makePos(5, 0)
    let code = InvalidInteractionDSL({message: "Parse error", position: Some(pos)})

    switch getPosition(code) {
    | Some(p) => assert(p.row == 5 && p.col == 0)
    | None => assert(false)
    }
  })
})

describe("ErrorTypes - Error Classification", () => {
  test("isWarning returns true for warnings", () => {
    let code = UnusualSpacing({position: makePos(1, 0), issue: "Tabs detected"})
    let error = make(code)

    assert(isWarning(error) == true)
    assert(isError(error) == false)
  })

  test("isError returns true for errors", () => {
    let code = EmptyButton({position: makePos(2, 3)})
    let error = make(code)

    assert(isError(error) == true)
    assert(isWarning(error) == false)
  })

  test("isWarning returns true for DeepNesting", () => {
    let code = DeepNesting({depth: 6, position: makePos(10, 5)})
    let error = make(code)

    assert(isWarning(error) == true)
  })
})

describe("ErrorTypes - Error Code Names", () => {
  test("getCodeName returns correct name for UncloseBox", () => {
    let code = UncloseBox({corner: makePos(1, 0), direction: "top"})
    assert(getCodeName(code) == "UncloseBox")
  })

  test("getCodeName returns correct name for MismatchedWidth", () => {
    let code = MismatchedWidth({topLeft: makePos(1, 0), topWidth: 10, bottomWidth: 8})
    assert(getCodeName(code) == "MismatchedWidth")
  })

  test("getCodeName returns correct name for MisalignedPipe", () => {
    let code = MisalignedPipe({position: makePos(2, 5), expected: 5, actual: 6})
    assert(getCodeName(code) == "MisalignedPipe")
  })

  test("getCodeName returns correct name for OverlappingBoxes", () => {
    let code = OverlappingBoxes({
      box1Name: Some("Box1"),
      box2Name: Some("Box2"),
      position: makePos(3, 0),
    })
    assert(getCodeName(code) == "OverlappingBoxes")
  })

  test("getCodeName returns correct name for InvalidElement", () => {
    let code = InvalidElement({content: "invalid", position: makePos(5, 2)})
    assert(getCodeName(code) == "InvalidElement")
  })

  test("getCodeName returns correct name for UnclosedBracket", () => {
    let code = UnclosedBracket({opening: makePos(4, 3)})
    assert(getCodeName(code) == "UnclosedBracket")
  })

  test("getCodeName returns correct name for EmptyButton", () => {
    let code = EmptyButton({position: makePos(6, 4)})
    assert(getCodeName(code) == "EmptyButton")
  })

  test("getCodeName returns correct name for InvalidInteractionDSL", () => {
    let code = InvalidInteractionDSL({message: "Parse failed", position: None})
    assert(getCodeName(code) == "InvalidInteractionDSL")
  })

  test("getCodeName returns correct name for UnusualSpacing", () => {
    let code = UnusualSpacing({position: makePos(8, 0), issue: "Tabs"})
    assert(getCodeName(code) == "UnusualSpacing")
  })

  test("getCodeName returns correct name for DeepNesting", () => {
    let code = DeepNesting({depth: 5, position: makePos(10, 2)})
    assert(getCodeName(code) == "DeepNesting")
  })
})

describe("ErrorTypes - Context Data Preservation", () => {
  test("UncloseBox preserves corner and direction", () => {
    let pos = makePos(5, 3)
    let code = UncloseBox({corner: pos, direction: "bottom"})

    switch code {
    | UncloseBox({corner, direction}) => {
        assert(corner.row == 5 && corner.col == 3)
        assert(direction == "bottom")
      }
    | _ => assert(false)
    }
  })

  test("MismatchedWidth preserves width data", () => {
    let code = MismatchedWidth({
      topLeft: makePos(1, 0),
      topWidth: 15,
      bottomWidth: 12,
    })

    switch code {
    | MismatchedWidth({topWidth, bottomWidth}) => {
        assert(topWidth == 15)
        assert(bottomWidth == 12)
      }
    | _ => assert(false)
    }
  })

  test("MisalignedPipe preserves expected and actual columns", () => {
    let code = MisalignedPipe({
      position: makePos(3, 7),
      expected: 5,
      actual: 7,
    })

    switch code {
    | MisalignedPipe({expected, actual}) => {
        assert(expected == 5)
        assert(actual == 7)
      }
    | _ => assert(false)
    }
  })

  test("OverlappingBoxes preserves box names", () => {
    let code = OverlappingBoxes({
      box1Name: Some("LoginBox"),
      box2Name: None,
      position: makePos(10, 0),
    })

    switch code {
    | OverlappingBoxes({box1Name, box2Name}) => {
        assert(box1Name == Some("LoginBox"))
        assert(box2Name == None)
      }
    | _ => assert(false)
    }
  })

  test("DeepNesting preserves depth information", () => {
    let code = DeepNesting({depth: 7, position: makePos(20, 5)})

    switch code {
    | DeepNesting({depth}) => assert(depth == 7)
    | _ => assert(false)
    }
  })

  test("UnusualSpacing preserves issue description", () => {
    let code = UnusualSpacing({
      position: makePos(2, 0),
      issue: "Mixed tabs and spaces detected",
    })

    switch code {
    | UnusualSpacing({issue}) => assert(issue == "Mixed tabs and spaces detected")
    | _ => assert(false)
    }
  })
})
