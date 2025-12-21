// Core Types Test Suite
// Tests for all type definitions and their behavior

open Jest
open Expect

describe("Types - cellChar variant", () => {
  test("Corner variant can be created", () => {
    let cell = Corner
    expect(cell)->toBe(Corner)
  })

  test("HLine variant can be created", () => {
    let cell = HLine
    expect(cell)->toBe(HLine)
  })

  test("VLine variant can be created", () => {
    let cell = VLine
    expect(cell)->toBe(VLine)
  })

  test("Divider variant can be created", () => {
    let cell = Divider
    expect(cell)->toBe(Divider)
  })

  test("Space variant can be created", () => {
    let cell = Space
    expect(cell)->toBe(Space)
  })

  test("Char variant can be created with content", () => {
    let cell = Char("a")
    expect(cell)->toEqual(Char("a"))
  })

  test("cellChar variants are distinct", () => {
    expect(Corner)->not->toBe(HLine)
    expect(HLine)->not->toBe(VLine)
    expect(VLine)->not->toBe(Divider)
    expect(Divider)->not->toBe(Space)
  })

  test("Char variant with different content are distinct", () => {
    expect(Char("a"))->not->toEqual(Char("b"))
  })

  test("pattern matching on cellChar works", () => {
    let classify = cell =>
      switch cell {
      | Corner => "corner"
      | HLine => "hline"
      | VLine => "vline"
      | Divider => "divider"
      | Space => "space"
      | Char(_) => "char"
      }

    expect(classify(Corner))->toBe("corner")
    expect(classify(HLine))->toBe("hline")
    expect(classify(VLine))->toBe("vline")
    expect(classify(Divider))->toBe("divider")
    expect(classify(Space))->toBe("space")
    expect(classify(Char("x")))->toBe("char")
  })

  test("extracting content from Char variant", () => {
    let cell = Char("hello")
    switch cell {
    | Char(content) => expect(content)->toBe("hello")
    | _ => fail("Expected Char variant")
    }
  })
})

describe("Types - alignment variant", () => {
  test("Left alignment can be created", () => {
    let align = Left
    expect(align)->toBe(Left)
  })

  test("Center alignment can be created", () => {
    let align = Center
    expect(align)->toBe(Center)
  })

  test("Right alignment can be created", () => {
    let align = Right
    expect(align)->toBe(Right)
  })

  test("alignment variants are distinct", () => {
    expect(Left)->not->toBe(Center)
    expect(Center)->not->toBe(Right)
    expect(Right)->not->toBe(Left)
  })

  test("pattern matching on alignment works", () => {
    let toString = align =>
      switch align {
      | Left => "left"
      | Center => "center"
      | Right => "right"
      }

    expect(toString(Left))->toBe("left")
    expect(toString(Center))->toBe("center")
    expect(toString(Right))->toBe("right")
  })
})

describe("Types - position record", () => {
  test("position can be created", () => {
    let pos = {row: 5, col: 10}
    expect(pos.row)->toBe(5)
    expect(pos.col)->toBe(10)
  })

  test("position equality", () => {
    let pos1 = {row: 5, col: 10}
    let pos2 = {row: 5, col: 10}
    expect(pos1)->toEqual(pos2)
  })

  test("position inequality", () => {
    let pos1 = {row: 5, col: 10}
    let pos2 = {row: 5, col: 11}
    expect(pos1)->not->toEqual(pos2)
  })
})

describe("Types - bounds record", () => {
  test("bounds can be created", () => {
    let b = {top: 0, left: 0, bottom: 10, right: 20}
    expect(b.top)->toBe(0)
    expect(b.left)->toBe(0)
    expect(b.bottom)->toBe(10)
    expect(b.right)->toBe(20)
  })

  test("bounds equality", () => {
    let b1 = {top: 0, left: 0, bottom: 10, right: 20}
    let b2 = {top: 0, left: 0, bottom: 10, right: 20}
    expect(b1)->toEqual(b2)
  })

  test("bounds inequality", () => {
    let b1 = {top: 0, left: 0, bottom: 10, right: 20}
    let b2 = {top: 0, left: 0, bottom: 11, right: 20}
    expect(b1)->not->toEqual(b2)
  })
})

describe("Types - element variant", () => {
  test("Box element can be created", () => {
    let box = Box({
      name: Some("Login"),
      bounds: {top: 0, left: 0, bottom: 10, right: 20},
      children: [],
    })

    switch box {
    | Box({name}) =>
      switch name {
      | Some(n) => expect(n)->toBe("Login")
      | None => fail("Expected Some name")
      }
    | _ => fail("Expected Box variant")
    }
  })

  test("Box element with no name", () => {
    let box = Box({
      name: None,
      bounds: {top: 0, left: 0, bottom: 10, right: 20},
      children: [],
    })

    switch box {
    | Box({name}) => expect(name)->toBe(None)
    | _ => fail("Expected Box variant")
    }
  })

  test("Button element can be created", () => {
    let button = Button({
      id: "submit",
      text: "Submit",
      position: {row: 5, col: 10},
      align: Center,
    })

    switch button {
    | Button({id, text, align}) => {
        expect(id)->toBe("submit")
        expect(text)->toBe("Submit")
        expect(align)->toBe(Center)
      }
    | _ => fail("Expected Button variant")
    }
  })

  test("Input element can be created", () => {
    let input = Input({
      id: "email",
      placeholder: Some("Enter email"),
      position: {row: 3, col: 5},
    })

    switch input {
    | Input({id, placeholder}) => {
        expect(id)->toBe("email")
        switch placeholder {
        | Some(p) => expect(p)->toBe("Enter email")
        | None => fail("Expected Some placeholder")
        }
      }
    | _ => fail("Expected Input variant")
    }
  })

  test("Link element can be created", () => {
    let link = Link({
      id: "forgot-password",
      text: "Forgot Password?",
      position: {row: 8, col: 15},
      align: Right,
    })

    switch link {
    | Link({id, text, align}) => {
        expect(id)->toBe("forgot-password")
        expect(text)->toBe("Forgot Password?")
        expect(align)->toBe(Right)
      }
    | _ => fail("Expected Link variant")
    }
  })

  test("Checkbox element can be created", () => {
    let checkbox = Checkbox({
      checked: true,
      label: "Remember me",
      position: {row: 6, col: 5},
    })

    switch checkbox {
    | Checkbox({checked, label}) => {
        expect(checked)->toBe(true)
        expect(label)->toBe("Remember me")
      }
    | _ => fail("Expected Checkbox variant")
    }
  })

  test("Text element can be created", () => {
    let text = Text({
      content: "Welcome",
      emphasis: false,
      position: {row: 1, col: 5},
      align: Left,
    })

    switch text {
    | Text({content, emphasis, align}) => {
        expect(content)->toBe("Welcome")
        expect(emphasis)->toBe(false)
        expect(align)->toBe(Left)
      }
    | _ => fail("Expected Text variant")
    }
  })

  test("Text element with emphasis", () => {
    let text = Text({
      content: "Important",
      emphasis: true,
      position: {row: 1, col: 5},
      align: Center,
    })

    switch text {
    | Text({emphasis}) => expect(emphasis)->toBe(true)
    | _ => fail("Expected Text variant")
    }
  })

  test("Divider element can be created", () => {
    let divider = Divider({position: {row: 5, col: 0}})

    switch divider {
    | Divider({position}) => expect(position.row)->toBe(5)
    | _ => fail("Expected Divider variant")
    }
  })

  test("Row element can be created", () => {
    let row = Row({
      children: [],
      align: Center,
    })

    switch row {
    | Row({align}) => expect(align)->toBe(Center)
    | _ => fail("Expected Row variant")
    }
  })

  test("Section element can be created", () => {
    let section = Section({
      name: "Header",
      children: [],
    })

    switch section {
    | Section({name}) => expect(name)->toBe("Header")
    | _ => fail("Expected Section variant")
    }
  })

  test("Box can contain nested elements", () => {
    let button = Button({
      id: "submit",
      text: "Submit",
      position: {row: 5, col: 10},
      align: Center,
    })

    let box = Box({
      name: Some("Form"),
      bounds: {top: 0, left: 0, bottom: 10, right: 20},
      children: [button],
    })

    switch box {
    | Box({children}) => expect(Array.length(children))->toBe(1)
    | _ => fail("Expected Box variant")
    }
  })

  test("pattern matching on element types", () => {
    let getType = element =>
      switch element {
      | Box(_) => "box"
      | Button(_) => "button"
      | Input(_) => "input"
      | Link(_) => "link"
      | Checkbox(_) => "checkbox"
      | Text(_) => "text"
      | Divider(_) => "divider"
      | Row(_) => "row"
      | Section(_) => "section"
      }

    expect(getType(Box({name: None, bounds: {top: 0, left: 0, bottom: 1, right: 1}, children: []})))->toBe("box")
    expect(getType(Button({id: "b", text: "B", position: {row: 0, col: 0}, align: Left})))->toBe("button")
    expect(getType(Input({id: "i", placeholder: None, position: {row: 0, col: 0}})))->toBe("input")
    expect(getType(Link({id: "l", text: "L", position: {row: 0, col: 0}, align: Left})))->toBe("link")
    expect(getType(Checkbox({checked: false, label: "C", position: {row: 0, col: 0}})))->toBe("checkbox")
    expect(getType(Text({content: "T", emphasis: false, position: {row: 0, col: 0}, align: Left})))->toBe("text")
    expect(getType(Divider({position: {row: 0, col: 0}})))->toBe("divider")
    expect(getType(Row({children: [], align: Left})))->toBe("row")
    expect(getType(Section({name: "S", children: []})))->toBe("section")
  })
})

describe("Types - scene record", () => {
  test("scene can be created", () => {
    let scene = {
      id: "login",
      title: "Login Page",
      transition: "fade",
      elements: [],
    }

    expect(scene.id)->toBe("login")
    expect(scene.title)->toBe("Login Page")
    expect(scene.transition)->toBe("fade")
    expect(Array.length(scene.elements))->toBe(0)
  })

  test("scene can contain elements", () => {
    let button = Button({
      id: "submit",
      text: "Submit",
      position: {row: 5, col: 10},
      align: Center,
    })

    let scene = {
      id: "login",
      title: "Login Page",
      transition: "fade",
      elements: [button],
    }

    expect(Array.length(scene.elements))->toBe(1)
  })

  test("scene equality", () => {
    let scene1 = {
      id: "login",
      title: "Login",
      transition: "fade",
      elements: [],
    }

    let scene2 = {
      id: "login",
      title: "Login",
      transition: "fade",
      elements: [],
    }

    expect(scene1)->toEqual(scene2)
  })
})

describe("Types - ast record", () => {
  test("ast can be created with empty scenes", () => {
    let ast = {scenes: []}
    expect(Array.length(ast.scenes))->toBe(0)
  })

  test("ast can contain multiple scenes", () => {
    let scene1 = {
      id: "login",
      title: "Login",
      transition: "fade",
      elements: [],
    }

    let scene2 = {
      id: "home",
      title: "Home",
      transition: "slide",
      elements: [],
    }

    let ast = {scenes: [scene1, scene2]}
    expect(Array.length(ast.scenes))->toBe(2)
  })

  test("ast scenes maintain order", () => {
    let scene1 = {
      id: "login",
      title: "Login",
      transition: "fade",
      elements: [],
    }

    let scene2 = {
      id: "home",
      title: "Home",
      transition: "slide",
      elements: [],
    }

    let ast = {scenes: [scene1, scene2]}
    expect(ast.scenes[0].id)->toBe("login")
    expect(ast.scenes[1].id)->toBe("home")
  })
})

describe("Types - interactionVariant", () => {
  test("Primary variant can be created", () => {
    let variant = Primary
    expect(variant)->toBe(Primary)
  })

  test("Secondary variant can be created", () => {
    let variant = Secondary
    expect(variant)->toBe(Secondary)
  })

  test("Ghost variant can be created", () => {
    let variant = Ghost
    expect(variant)->toBe(Ghost)
  })

  test("pattern matching on interactionVariant", () => {
    let toString = variant =>
      switch variant {
      | Primary => "primary"
      | Secondary => "secondary"
      | Ghost => "ghost"
      }

    expect(toString(Primary))->toBe("primary")
    expect(toString(Secondary))->toBe("secondary")
    expect(toString(Ghost))->toBe("ghost")
  })
})

describe("Types - interactionAction", () => {
  test("Goto action can be created", () => {
    let action = Goto({
      target: "home",
      transition: "fade",
      condition: Some("isValid"),
    })

    switch action {
    | Goto({target, transition, condition}) => {
        expect(target)->toBe("home")
        expect(transition)->toBe("fade")
        switch condition {
        | Some(c) => expect(c)->toBe("isValid")
        | None => fail("Expected Some condition")
        }
      }
    | _ => fail("Expected Goto variant")
    }
  })

  test("Back action can be created", () => {
    let action = Back
    expect(action)->toBe(Back)
  })

  test("Forward action can be created", () => {
    let action = Forward
    expect(action)->toBe(Forward)
  })

  test("Validate action can be created", () => {
    let action = Validate({fields: ["email", "password"]})

    switch action {
    | Validate({fields}) => {
        expect(Array.length(fields))->toBe(2)
        expect(fields[0])->toBe("email")
        expect(fields[1])->toBe("password")
      }
    | _ => fail("Expected Validate variant")
    }
  })

  test("Call action can be created", () => {
    let action = Call({
      function: "handleSubmit",
      args: ["arg1", "arg2"],
      condition: None,
    })

    switch action {
    | Call({function, args, condition}) => {
        expect(function)->toBe("handleSubmit")
        expect(Array.length(args))->toBe(2)
        expect(condition)->toBe(None)
      }
    | _ => fail("Expected Call variant")
    }
  })

  test("pattern matching on interactionAction", () => {
    let getType = action =>
      switch action {
      | Goto(_) => "goto"
      | Back => "back"
      | Forward => "forward"
      | Validate(_) => "validate"
      | Call(_) => "call"
      }

    expect(getType(Goto({target: "x", transition: "y", condition: None})))->toBe("goto")
    expect(getType(Back))->toBe("back")
    expect(getType(Forward))->toBe("forward")
    expect(getType(Validate({fields: []})))->toBe("validate")
    expect(getType(Call({function: "f", args: [], condition: None})))->toBe("call")
  })
})

describe("Types - interaction record", () => {
  test("interaction can be created", () => {
    let props = Js.Dict.empty()
    Js.Dict.set(props, "variant", Js.Json.string("primary"))

    let interaction = {
      elementId: "submit-button",
      properties: props,
      actions: [Back],
    }

    expect(interaction.elementId)->toBe("submit-button")
    expect(Array.length(interaction.actions))->toBe(1)
  })

  test("interaction with multiple actions", () => {
    let interaction = {
      elementId: "form",
      properties: Js.Dict.empty(),
      actions: [
        Validate({fields: ["email", "password"]}),
        Goto({target: "home", transition: "fade", condition: None}),
      ],
    }

    expect(Array.length(interaction.actions))->toBe(2)
  })
})

describe("Types - sceneInteractions record", () => {
  test("sceneInteractions can be created", () => {
    let sceneInteractions = {
      sceneId: "login",
      interactions: [],
    }

    expect(sceneInteractions.sceneId)->toBe("login")
    expect(Array.length(sceneInteractions.interactions))->toBe(0)
  })

  test("sceneInteractions can contain multiple interactions", () => {
    let interaction1 = {
      elementId: "email",
      properties: Js.Dict.empty(),
      actions: [],
    }

    let interaction2 = {
      elementId: "password",
      properties: Js.Dict.empty(),
      actions: [],
    }

    let sceneInteractions = {
      sceneId: "login",
      interactions: [interaction1, interaction2],
    }

    expect(Array.length(sceneInteractions.interactions))->toBe(2)
    expect(sceneInteractions.interactions[0].elementId)->toBe("email")
    expect(sceneInteractions.interactions[1].elementId)->toBe("password")
  })
})
