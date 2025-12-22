// Core Types Test Suite
// Tests for all type definitions and their behavior

open Vitest
open Types

describe("Types - cellChar variant", () => {
  test("Corner variant can be created", t => {
    let cell = Corner
    t->expect(cell)->Expect.toBe(Corner)
  })

  test("HLine variant can be created", t => {
    let cell = HLine
    t->expect(cell)->Expect.toBe(HLine)
  })

  test("VLine variant can be created", t => {
    let cell = VLine
    t->expect(cell)->Expect.toBe(VLine)
  })

  test("Divider variant can be created", t => {
    let cell: cellChar = Divider
    t->expect(cell)->Expect.toBe(Divider)
  })

  test("Space variant can be created", t => {
    let cell = Space
    t->expect(cell)->Expect.toBe(Space)
  })

  test("Char variant can be created with content", t => {
    let cell = Char("a")
    t->expect(cell)->Expect.toEqual(Char("a"))
  })

  test("cellChar variants are distinct", t => {
    let divider: cellChar = Divider
    t->expect(Corner)->Expect.not->Expect.toBe(HLine)
    t->expect(HLine)->Expect.not->Expect.toBe(VLine)
    t->expect(VLine)->Expect.not->Expect.toBe(divider)
    t->expect(divider)->Expect.not->Expect.toBe(Space)
  })

  test("Char variant with different content are distinct", t => {
    t->expect(Char("a"))->Expect.not->Expect.toEqual(Char("b"))
  })

  test("pattern matching on cellChar works", t => {
    let classify = cell =>
      switch cell {
      | Corner => "corner"
      | HLine => "hline"
      | VLine => "vline"
      | Divider => "divider"
      | Space => "space"
      | Char(_) => "char"
      }

    t->expect(classify(Corner))->Expect.toBe("corner")
    t->expect(classify(HLine))->Expect.toBe("hline")
    t->expect(classify(VLine))->Expect.toBe("vline")
    t->expect(classify(Divider))->Expect.toBe("divider")
    t->expect(classify(Space))->Expect.toBe("space")
    t->expect(classify(Char("x")))->Expect.toBe("char")
  })

  test("extracting content from Char variant", t => {
    let cell = Char("hello")
    switch cell {
    | Char(content) => t->expect(content)->Expect.toBe("hello")
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Char variant
    }
  })
})

describe("Types - alignment variant", () => {
  test("Left alignment can be created", t => {
    let align = Left
    t->expect(align)->Expect.toBe(Left)
  })

  test("Center alignment can be created", t => {
    let align = Center
    t->expect(align)->Expect.toBe(Center)
  })

  test("Right alignment can be created", t => {
    let align = Right
    t->expect(align)->Expect.toBe(Right)
  })

  test("alignment variants are distinct", t => {
    t->expect(Left)->Expect.not->Expect.toBe(Center)
    t->expect(Center)->Expect.not->Expect.toBe(Right)
    t->expect(Right)->Expect.not->Expect.toBe(Left)
  })

  test("pattern matching on alignment works", t => {
    let toString = align =>
      switch align {
      | Left => "left"
      | Center => "center"
      | Right => "right"
      }

    t->expect(toString(Left))->Expect.toBe("left")
    t->expect(toString(Center))->Expect.toBe("center")
    t->expect(toString(Right))->Expect.toBe("right")
  })
})

describe("Types - position record", () => {
  test("position can be created", t => {
    let pos: Position.t = {row: 5, col: 10}
    t->expect(pos.row)->Expect.toBe(5)
    t->expect(pos.col)->Expect.toBe(10)
  })

  test("position equality", t => {
    let pos1: Position.t = {row: 5, col: 10}
    let pos2: Position.t = {row: 5, col: 10}
    t->expect(pos1)->Expect.toEqual(pos2)
  })

  test("position inequality", t => {
    let pos1: Position.t = {row: 5, col: 10}
    let pos2: Position.t = {row: 5, col: 11}
    t->expect(pos1)->Expect.not->Expect.toEqual(pos2)
  })
})

describe("Types - bounds record", () => {
  test("bounds can be created", t => {
    let b: Bounds.t = {top: 0, left: 0, bottom: 10, right: 20}
    t->expect(b.top)->Expect.toBe(0)
    t->expect(b.left)->Expect.toBe(0)
    t->expect(b.bottom)->Expect.toBe(10)
    t->expect(b.right)->Expect.toBe(20)
  })

  test("bounds equality", t => {
    let b1: Bounds.t = {top: 0, left: 0, bottom: 10, right: 20}
    let b2: Bounds.t = {top: 0, left: 0, bottom: 10, right: 20}
    t->expect(b1)->Expect.toEqual(b2)
  })

  test("bounds inequality", t => {
    let b1: Bounds.t = {top: 0, left: 0, bottom: 10, right: 20}
    let b2: Bounds.t = {top: 0, left: 0, bottom: 11, right: 20}
    t->expect(b1)->Expect.not->Expect.toEqual(b2)
  })
})

describe("Types - element variant", () => {
  test("Box element can be created", t => {
    let box = Box({
      name: Some("Login"),
      bounds: {top: 0, left: 0, bottom: 10, right: 20},
      children: [],
    })

    switch box {
    | Box({name}) =>
      switch name {
      | Some(n) => t->expect(n)->Expect.toBe("Login")
      | None => t->expect(true)->Expect.toBe(false) // fail: Expected Some name
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Box variant
    }
  })

  test("Box element with no name", t => {
    let box = Box({
      name: None,
      bounds: {top: 0, left: 0, bottom: 10, right: 20},
      children: [],
    })

    switch box {
    | Box({name}) => t->expect(name)->Expect.toBe(None)
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Box variant
    }
  })

  test("Button element can be created", t => {
    let button = Button({
      id: "submit",
      text: "Submit",
      position: {row: 5, col: 10},
      align: Center,
      actions: [],
    })

    switch button {
    | Button({id, text, align}) => {
        t->expect(id)->Expect.toBe("submit")
        t->expect(text)->Expect.toBe("Submit")
        t->expect(align)->Expect.toBe(Center)
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Button variant
    }
  })

  test("Input element can be created", t => {
    let input = Input({
      id: "email",
      placeholder: Some("Enter email"),
      position: {row: 3, col: 5},
    })

    switch input {
    | Input({id, placeholder}) => {
        t->expect(id)->Expect.toBe("email")
        switch placeholder {
        | Some(p) => t->expect(p)->Expect.toBe("Enter email")
        | None => t->expect(true)->Expect.toBe(false) // fail: Expected Some placeholder
        }
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input variant
    }
  })

  test("Link element can be created", t => {
    let link = Link({
      id: "forgot-password",
      text: "Forgot Password?",
      position: {row: 8, col: 15},
      align: Right,
      actions: [],
    })

    switch link {
    | Link({id, text, align}) => {
        t->expect(id)->Expect.toBe("forgot-password")
        t->expect(text)->Expect.toBe("Forgot Password?")
        t->expect(align)->Expect.toBe(Right)
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link variant
    }
  })

  test("Checkbox element can be created", t => {
    let checkbox = Checkbox({
      checked: true,
      label: "Remember me",
      position: {row: 6, col: 5},
    })

    switch checkbox {
    | Checkbox({checked, label}) => {
        t->expect(checked)->Expect.toBe(true)
        t->expect(label)->Expect.toBe("Remember me")
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox variant
    }
  })

  test("Text element can be created", t => {
    let text = Text({
      content: "Welcome",
      emphasis: false,
      position: {row: 1, col: 5},
      align: Left,
    })

    switch text {
    | Text({content, emphasis, align}) => {
        t->expect(content)->Expect.toBe("Welcome")
        t->expect(emphasis)->Expect.toBe(false)
        t->expect(align)->Expect.toBe(Left)
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Text variant
    }
  })

  test("Text element with emphasis", t => {
    let text = Text({
      content: "Important",
      emphasis: true,
      position: {row: 1, col: 5},
      align: Center,
    })

    switch text {
    | Text({emphasis}) => t->expect(emphasis)->Expect.toBe(true)
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Text variant
    }
  })

  test("Divider element can be created", t => {
    let divider = Divider({position: {row: 5, col: 0}})

    switch divider {
    | Divider({position}) => t->expect(position.row)->Expect.toBe(5)
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Divider variant
    }
  })

  test("Row element can be created", t => {
    let row = Row({
      children: [],
      align: Center,
    })

    switch row {
    | Row({align}) => t->expect(align)->Expect.toBe(Center)
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Row variant
    }
  })

  test("Section element can be created", t => {
    let section = Section({
      name: "Header",
      children: [],
    })

    switch section {
    | Section({name}) => t->expect(name)->Expect.toBe("Header")
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Section variant
    }
  })

  test("Box can contain nested elements", t => {
    let button = Button({
      id: "submit",
      text: "Submit",
      position: {row: 5, col: 10},
      align: Center,
      actions: [],
    })

    let box = Box({
      name: Some("Form"),
      bounds: {top: 0, left: 0, bottom: 10, right: 20},
      children: [button],
    })

    switch box {
    | Box({children}) => t->expect(Array.length(children))->Expect.toBe(1)
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Box variant
    }
  })

  test("pattern matching on element types", t => {
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

    t->expect(getType(Box({name: None, bounds: {top: 0, left: 0, bottom: 1, right: 1}, children: []})))->Expect.toBe("box")
    t->expect(getType(Button({id: "b", text: "B", position: {row: 0, col: 0}, align: Left, actions: []})))->Expect.toBe("button")
    t->expect(getType(Input({id: "i", placeholder: None, position: {row: 0, col: 0}})))->Expect.toBe("input")
    t->expect(getType(Link({id: "l", text: "L", position: {row: 0, col: 0}, align: Left, actions: []})))->Expect.toBe("link")
    t->expect(getType(Checkbox({checked: false, label: "C", position: {row: 0, col: 0}})))->Expect.toBe("checkbox")
    t->expect(getType(Text({content: "T", emphasis: false, position: {row: 0, col: 0}, align: Left})))->Expect.toBe("text")
    t->expect(getType(Divider({position: {row: 0, col: 0}})))->Expect.toBe("divider")
    t->expect(getType(Row({children: [], align: Left})))->Expect.toBe("row")
    t->expect(getType(Section({name: "S", children: []})))->Expect.toBe("section")
  })
})

describe("Types - scene record", () => {
  test("scene can be created", t => {
    let scene: scene = {
      id: "login",
      title: "Login Page",
      transition: "fade",
      device: Desktop,
      elements: [],
    }

    t->expect(scene.id)->Expect.toBe("login")
    t->expect(scene.title)->Expect.toBe("Login Page")
    t->expect(scene.transition)->Expect.toBe("fade")
    t->expect(Array.length(scene.elements))->Expect.toBe(0)
  })

  test("scene can contain elements", t => {
    let button = Button({
      id: "submit",
      text: "Submit",
      position: {row: 5, col: 10},
      align: Center,
      actions: [],
    })

    let scene: scene = {
      id: "login",
      title: "Login Page",
      transition: "fade",
      device: Desktop,
      elements: [button],
    }

    t->expect(Array.length(scene.elements))->Expect.toBe(1)
  })

  test("scene equality", t => {
    let scene1: scene = {
      id: "login",
      title: "Login",
      transition: "fade",
      device: Desktop,
      elements: [],
    }

    let scene2: scene = {
      id: "login",
      title: "Login",
      transition: "fade",
      device: Desktop,
      elements: [],
    }

    t->expect(scene1)->Expect.toEqual(scene2)
  })
})

describe("Types - ast record", () => {
  test("ast can be created with empty scenes", t => {
    let ast = {scenes: []}
    t->expect(Array.length(ast.scenes))->Expect.toBe(0)
  })

  test("ast can contain multiple scenes", t => {
    let scene1: scene = {
      id: "login",
      title: "Login",
      transition: "fade",
      device: Desktop,
      elements: [],
    }

    let scene2: scene = {
      id: "home",
      title: "Home",
      transition: "slide",
      device: Desktop,
      elements: [],
    }

    let ast: ast = {scenes: [scene1, scene2]}
    t->expect(Array.length(ast.scenes))->Expect.toBe(2)
  })

  test("ast scenes maintain order", t => {
    let scene1: scene = {
      id: "login",
      title: "Login",
      transition: "fade",
      device: Desktop,
      elements: [],
    }

    let scene2: scene = {
      id: "home",
      title: "Home",
      transition: "slide",
      device: Desktop,
      elements: [],
    }

    let ast: ast = {scenes: [scene1, scene2]}
    t->expect(Array.getUnsafe(ast.scenes, 0).id)->Expect.toBe("login")
    t->expect(Array.getUnsafe(ast.scenes, 1).id)->Expect.toBe("home")
  })
})

describe("Types - interactionVariant", () => {
  test("Primary variant can be created", t => {
    let variant = Primary
    t->expect(variant)->Expect.toBe(Primary)
  })

  test("Secondary variant can be created", t => {
    let variant = Secondary
    t->expect(variant)->Expect.toBe(Secondary)
  })

  test("Ghost variant can be created", t => {
    let variant = Ghost
    t->expect(variant)->Expect.toBe(Ghost)
  })

  test("pattern matching on interactionVariant", t => {
    let toString = variant =>
      switch variant {
      | Primary => "primary"
      | Secondary => "secondary"
      | Ghost => "ghost"
      }

    t->expect(toString(Primary))->Expect.toBe("primary")
    t->expect(toString(Secondary))->Expect.toBe("secondary")
    t->expect(toString(Ghost))->Expect.toBe("ghost")
  })
})

describe("Types - interactionAction", () => {
  test("Goto action can be created", t => {
    let action = Goto({
      target: "home",
      transition: "fade",
      condition: Some("isValid"),
    })

    switch action {
    | Goto({target, transition, condition}) => {
        t->expect(target)->Expect.toBe("home")
        t->expect(transition)->Expect.toBe("fade")
        switch condition {
        | Some(c) => t->expect(c)->Expect.toBe("isValid")
        | None => t->expect(true)->Expect.toBe(false) // fail: Expected Some condition
        }
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Goto variant
    }
  })

  test("Back action can be created", t => {
    let action = Back
    t->expect(action)->Expect.toBe(Back)
  })

  test("Forward action can be created", t => {
    let action = Forward
    t->expect(action)->Expect.toBe(Forward)
  })

  test("Validate action can be created", t => {
    let action = Validate({fields: ["email", "password"]})

    switch action {
    | Validate({fields}) => {
        t->expect(Array.length(fields))->Expect.toBe(2)
        t->expect(Array.getUnsafe(fields, 0))->Expect.toBe("email")
        t->expect(Array.getUnsafe(fields, 1))->Expect.toBe("password")
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Validate variant
    }
  })

  test("Call action can be created", t => {
    let action = Call({
      function: "handleSubmit",
      args: ["arg1", "arg2"],
      condition: None,
    })

    switch action {
    | Call({function, args, condition}) => {
        t->expect(function)->Expect.toBe("handleSubmit")
        t->expect(Array.length(args))->Expect.toBe(2)
        t->expect(condition)->Expect.toBe(None)
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Call variant
    }
  })

  test("pattern matching on interactionAction", t => {
    let getType = action =>
      switch action {
      | Goto(_) => "goto"
      | Back => "back"
      | Forward => "forward"
      | Validate(_) => "validate"
      | Call(_) => "call"
      }

    t->expect(getType(Goto({target: "x", transition: "y", condition: None})))->Expect.toBe("goto")
    t->expect(getType(Back))->Expect.toBe("back")
    t->expect(getType(Forward))->Expect.toBe("forward")
    t->expect(getType(Validate({fields: []})))->Expect.toBe("validate")
    t->expect(getType(Call({function: "f", args: [], condition: None})))->Expect.toBe("call")
  })
})

describe("Types - interaction record", () => {
  test("interaction can be created", t => {
    let props = Js.Dict.empty()
    Js.Dict.set(props, "variant", Js.Json.string("primary"))

    let interaction = {
      elementId: "submit-button",
      properties: props,
      actions: [Back],
    }

    t->expect(interaction.elementId)->Expect.toBe("submit-button")
    t->expect(Array.length(interaction.actions))->Expect.toBe(1)
  })

  test("interaction with multiple actions", t => {
    let interaction = {
      elementId: "form",
      properties: Js.Dict.empty(),
      actions: [
        Validate({fields: ["email", "password"]}),
        Goto({target: "home", transition: "fade", condition: None}),
      ],
    }

    t->expect(Array.length(interaction.actions))->Expect.toBe(2)
  })
})

describe("Types - sceneInteractions record", () => {
  test("sceneInteractions can be created", t => {
    let sceneInteractions = {
      sceneId: "login",
      interactions: [],
    }

    t->expect(sceneInteractions.sceneId)->Expect.toBe("login")
    t->expect(Array.length(sceneInteractions.interactions))->Expect.toBe(0)
  })

  test("sceneInteractions can contain multiple interactions", t => {
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

    t->expect(Array.length(sceneInteractions.interactions))->Expect.toBe(2)
    t->expect(Array.getUnsafe(sceneInteractions.interactions, 0).elementId)->Expect.toBe("email")
    t->expect(Array.getUnsafe(sceneInteractions.interactions, 1).elementId)->Expect.toBe("password")
  })
})
