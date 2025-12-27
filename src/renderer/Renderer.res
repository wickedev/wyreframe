// Renderer.res
// HTML/DOM Renderer for Wyreframe AST
// Converts parsed wireframe AST into interactive HTML elements

open Types

// ============================================================================
// DOM Bindings (must be defined first for type references)
// ============================================================================

module DomBindings = {
  type element
  type document
  type style
  type classList
  type dataset

  @val external document: document = "document"

  @send external createElement: (document, string) => element = "createElement"
  @send external getElementById: (document, string) => Nullable.t<element> = "getElementById"
  @send external appendChild: (element, element) => unit = "appendChild"
  @send external querySelector: (element, string) => Nullable.t<element> = "querySelector"

  @set external setClassName: (element, string) => unit = "className"
  @set external setId: (element, string) => unit = "id"
  @set external setTextContent: (element, string) => unit = "textContent"
  @set external setInnerHTML: (element, string) => unit = "innerHTML"
  @set external setHref: (element, string) => unit = "href"
  @set external setPlaceholder: (element, string) => unit = "placeholder"
  @set external setType: (element, string) => unit = "type"
  @set external setChecked: (element, bool) => unit = "checked"

  @get external classList: element => classList = "classList"
  @send external add: (classList, string) => unit = "add"
  @send external remove: (classList, string) => unit = "remove"
  @send external contains: (classList, string) => bool = "contains"

  @get external dataset: element => dataset = "dataset"
  @set_index external setDataAttr: (dataset, string, string) => unit = ""

  @get external head: document => element = "head"
  @send external addEventListener: (element, string, 'event => unit) => unit = "addEventListener"
  @send external preventDefault: 'event => unit = "preventDefault"
}

// ============================================================================
// Render Options
// ============================================================================

/**
 * Scene change callback type.
 * Called when navigating between scenes.
 * @param fromScene The scene ID navigating from (None if initial)
 * @param toScene The scene ID navigating to
 */
type onSceneChangeCallback = (option<string>, string) => unit

/**
 * Dead end click info type.
 * Contains information about the clicked element that has no navigation target.
 */
type deadEndClickInfo = {
  sceneId: string,
  elementId: string,
  elementText: string,
  elementType: [#button | #link],
}

/**
 * Dead end click callback type.
 * Called when a button or link without navigation target is clicked.
 * @param info Information about the clicked element and current scene
 */
type onDeadEndClickCallback = deadEndClickInfo => unit

/**
 * Configuration for the rendering process.
 */
type renderOptions = {
  theme: option<string>,
  interactive: bool,
  injectStyles: bool,
  containerClass: option<string>,
  onSceneChange: option<onSceneChangeCallback>,
  onDeadEndClick: option<onDeadEndClickCallback>,
  device: option<deviceType>,
}

/**
 * Default render options.
 */
let defaultOptions: renderOptions = {
  theme: None,
  interactive: true,
  injectStyles: true,
  containerClass: None,
  onSceneChange: None,
  onDeadEndClick: None,
  device: None,
}

// ============================================================================
// Scene Manager Type
// ============================================================================

/**
 * Scene management interface returned by render function.
 */
type sceneManager = {
  goto: string => unit,
  back: unit => unit,
  forward: unit => unit,
  refresh: unit => unit,
  canGoBack: unit => bool,
  canGoForward: unit => bool,
  getCurrentScene: unit => option<string>,
  getSceneIds: unit => array<string>,
}

/**
 * Render result containing the root element and scene manager.
 */
type renderResult = {
  root: DomBindings.element,
  sceneManager: sceneManager,
}

// ============================================================================
// CSS Styles
// ============================================================================

let defaultStyles = `
  .wf-app { font-family: monospace; position: relative; overflow: hidden; background: #fff; color: #333; font-size: 14px; margin: 0 auto; }
  .wf-app.wf-device-desktop { width: 1440px; height: 900px; max-width: 100%; aspect-ratio: 16/10; }
  .wf-app.wf-device-laptop { width: 1280px; height: 773px; max-width: 100%; aspect-ratio: 16/10; }
  .wf-app.wf-device-tablet { width: 768px; height: 1064px; max-width: 100%; aspect-ratio: 3/4; }
  .wf-app.wf-device-tablet-landscape { width: 1024px; height: 768px; max-width: 100%; aspect-ratio: 4/3; }
  .wf-app.wf-device-mobile { width: 375px; height: 812px; max-width: 100%; aspect-ratio: 375/812; }
  .wf-app.wf-device-mobile-landscape { width: 812px; height: 375px; max-width: 100%; aspect-ratio: 812/375; }
  .wf-scene { position: absolute; top:0; left:0; width:100%; height:100%; padding:16px; box-sizing:border-box; opacity:0; pointer-events:none; transition: opacity 0.3s ease, transform 0.3s ease; overflow-y: auto; }
  .wf-scene.active { opacity:1; pointer-events:auto; }
  .wf-box { border:1px solid #333; padding:12px; margin:8px 0; background:#fff; }
  .wf-box-named { position: relative; margin-top: 16px; }
  .wf-box-named::before { content: attr(data-name); position: absolute; top: -10px; left: 8px; background: #fff; padding: 0 4px; font-size: 12px; color: #666; }
  .wf-row { display:flex; gap:12px; align-items:center; margin:4px 0; }
  .wf-column { flex:1; display:flex; flex-direction:column; gap:4px; }
  .wf-button { display:block; width:fit-content; padding:8px 16px; background:#fff; color:#333; border:1px solid #333; font: inherit; cursor:pointer; margin:4px 0; }
  .wf-button.secondary { background:#eee; }
  .wf-button.ghost { background:transparent; border:1px dashed #999; color:#666; }
  .wf-input { width:100%; padding:8px; border:1px solid #333; font: inherit; box-sizing:border-box; margin:4px 0; }
  .wf-link { display:block; color:#333; text-decoration:underline; cursor:pointer; margin:4px 0; }
  .wf-row .wf-button { display:inline-block; margin:0; }
  .wf-row .wf-link { display:inline; margin:0 8px; }
  .wf-text { margin:4px 0; line-height:1.4; }
  .wf-text.emphasis { font-weight:bold; }
  .wf-spacer { min-height:1em; }
  .wf-divider { border:none; border-top:1px solid #333; margin:12px 0; }
  .wf-section { border:1px solid #333; margin:8px 0; }
  .wf-section-header { background:#fff; padding:4px 8px; font-size:12px; color:#666; border-bottom:1px solid #333; }
  .wf-section-content { padding:8px; }
  .wf-checkbox { display:flex; align-items:center; gap:8px; margin:4px 0; cursor:pointer; }
  .align-center { text-align:center; }
  .align-right { text-align:right; }
  .wf-row.align-center { justify-content:center; }
  .wf-row.align-right { justify-content:flex-end; }
  .wf-button.align-center, .wf-link.align-center { margin-left:auto; margin-right:auto; }
  .wf-button.align-right, .wf-link.align-right { margin-left:auto; margin-right:0; }
`

// ============================================================================
// Helper Functions
// ============================================================================

// Noise text filter - filters out box border characters
// Note: Empty lines are NOT noise - they represent intentional vertical spacing (Issue #16)
let isNoiseText = (content: string): bool => {
  let trimmed = content->String.trim
  if trimmed == "" {
    // Empty lines should be preserved as vertical spacing
    false
  } else {
    // Box border patterns: +---+, |, ===, etc.
    let borderPattern = %re("/^[+|=\-\s]+$/")
    let hasPipeOrPlus = %re("/[+|]/")

    Js.Re.test_(borderPattern, trimmed) ||
    Js.Re.test_(hasPipeOrPlus, trimmed)
  }
}

// Check if a box contains only inputs (should unwrap and render as inputs directly)
let isInputOnlyBox = (elem: element): bool => {
  switch elem {
  | Box({name: None, children}) =>
    // Check if all children are Inputs (allows for multiple inputs in a box)
    children->Array.length > 0 &&
    children->Array.every(child => {
      switch child {
      | Input(_) => true
      | _ => false
      }
    })
  | _ => false
  }
}

// Get inputs from a box that contains only inputs
let getInputsFromBox = (elem: element): array<element> => {
  switch elem {
  | Box({name: None, children}) => children
  | _ => []
  }
}

let alignmentToClass = (align: alignment): option<string> => {
  switch align {
  | Left => None
  | Center => Some("align-center")
  | Right => Some("align-right")
  }
}

let applyAlignment = (el: DomBindings.element, align: alignment): unit => {
  switch alignmentToClass(align) {
  | Some(cls) => el->DomBindings.classList->DomBindings.add(cls)
  | None => ()
  }
}

/**
 * Convert device type to CSS class name.
 */
let deviceTypeToClass = (device: deviceType): string => {
  switch device {
  | Desktop => "wf-device-desktop"
  | Laptop => "wf-device-laptop"
  | Tablet => "wf-device-tablet"
  | TabletLandscape => "wf-device-tablet-landscape"
  | Mobile => "wf-device-mobile"
  | MobileLandscape => "wf-device-mobile-landscape"
  | Custom(w, h) => "wf-device-custom-" ++ Int.toString(w) ++ "x" ++ Int.toString(h)
  }
}

// ============================================================================
// Action Handler Type
// ============================================================================

/**
 * Action handler function type - called when an element's action is triggered.
 * The function receives the action and should execute it (e.g., goto scene).
 */
type actionHandler = interactionAction => unit

/**
 * Dead end handler function type - called when an element without navigation is clicked.
 * Receives element ID, text, and type.
 */
type deadEndHandler = (string, string, [#button | #link]) => unit

/**
 * Check if an action is a navigation action (Goto, Back, Forward).
 */
let isNavigationAction = (action: interactionAction): bool => {
  switch action {
  | Goto(_) | Back | Forward => true
  | Validate(_) | Call(_) => false
  }
}

/**
 * Check if actions array has any navigation actions.
 */
let hasNavigationAction = (actions: array<interactionAction>): bool => {
  actions->Array.some(isNavigationAction)
}

// ============================================================================
// Element Rendering
// ============================================================================

let rec renderElement = (
  elem: element,
  ~onAction: option<actionHandler>=?,
  ~onDeadEnd: option<deadEndHandler>=?,
): option<DomBindings.element> => {
  // Handle input-only boxes by rendering children directly in a wrapper
  if isInputOnlyBox(elem) {
    let inputs = getInputsFromBox(elem)
    // If only one input, render it directly
    switch inputs->Array.get(0) {
    | Some(input) => renderElement(input, ~onAction?, ~onDeadEnd?)
    | None => None
    }
  } else {
    switch elem {
    | Box({name, children, _}) => {
        let div = DomBindings.document->DomBindings.createElement("div")
        div->DomBindings.setClassName("wf-box")

        switch name {
        | Some(n) => {
            div->DomBindings.classList->DomBindings.add("wf-box-named")
            div->DomBindings.dataset->DomBindings.setDataAttr("name", n)
          }
        | None => ()
        }

        children->Array.forEach(child => {
          switch renderElement(child, ~onAction?, ~onDeadEnd?) {
          | Some(el) => div->DomBindings.appendChild(el)
          | None => ()
          }
        })

        Some(div)
      }

  | Button({id, text, align, actions, _}) => {
      let btn = DomBindings.document->DomBindings.createElement("button")
      btn->DomBindings.setClassName("wf-button")
      btn->DomBindings.setId(id)
      btn->DomBindings.setTextContent(text)
      applyAlignment(btn, align)

      // Check if button has navigation actions
      let hasNavigation = hasNavigationAction(actions)

      if hasNavigation {
        // Attach click handler for navigation actions
        switch onAction {
        | Some(handler) => {
            btn->DomBindings.addEventListener("click", _event => {
              // Execute first action (most common case)
              switch actions->Array.get(0) {
              | Some(action) => handler(action)
              | None => ()
              }
            })
          }
        | None => ()
        }
      } else {
        // No navigation - call dead end handler
        switch onDeadEnd {
        | Some(handler) => {
            btn->DomBindings.addEventListener("click", _event => {
              handler(id, text, #button)
            })
          }
        | None => ()
        }
      }

      Some(btn)
    }

  | Input({id, placeholder, _}) => {
      let input = DomBindings.document->DomBindings.createElement("input")
      input->DomBindings.setClassName("wf-input")
      input->DomBindings.setId(id)
      switch placeholder {
      | Some(p) => input->DomBindings.setPlaceholder(p)
      | None => ()
      }
      Some(input)
    }

  | Link({id, text, align, actions, _}) => {
      let link = DomBindings.document->DomBindings.createElement("a")
      link->DomBindings.setClassName("wf-link")
      link->DomBindings.setId(id)
      link->DomBindings.setHref("#")
      link->DomBindings.setTextContent(text)
      applyAlignment(link, align)

      // Check if link has navigation actions
      let hasNavigation = hasNavigationAction(actions)

      if hasNavigation {
        // Attach click handler for navigation actions
        switch onAction {
        | Some(handler) => {
            link->DomBindings.addEventListener("click", event => {
              DomBindings.preventDefault(event)
              // Execute first action
              switch actions->Array.get(0) {
              | Some(action) => handler(action)
              | None => ()
              }
            })
          }
        | None => ()
        }
      } else {
        // No navigation - call dead end handler
        switch onDeadEnd {
        | Some(handler) => {
            link->DomBindings.addEventListener("click", event => {
              DomBindings.preventDefault(event)
              handler(id, text, #link)
            })
          }
        | None => ()
        }
      }

      Some(link)
    }

  | Checkbox({checked, label, _}) => {
      let labelEl = DomBindings.document->DomBindings.createElement("label")
      labelEl->DomBindings.setClassName("wf-checkbox")

      let input = DomBindings.document->DomBindings.createElement("input")
      input->DomBindings.setType("checkbox")
      input->DomBindings.setChecked(checked)

      let span = DomBindings.document->DomBindings.createElement("span")
      span->DomBindings.setTextContent(label)

      labelEl->DomBindings.appendChild(input)
      labelEl->DomBindings.appendChild(span)
      Some(labelEl)
    }

  | Text({content, emphasis, align, _}) => {
      // Filter noise text (box borders, etc.)
      if isNoiseText(content) {
        None
      } else {
        let p = DomBindings.document->DomBindings.createElement("p")
        p->DomBindings.setClassName("wf-text")
        if emphasis {
          p->DomBindings.classList->DomBindings.add("emphasis")
        }
        applyAlignment(p, align)
        // Issue #16: Empty lines should render with visible height as spacers
        let trimmed = content->String.trim
        if trimmed === "" {
          p->DomBindings.classList->DomBindings.add("wf-spacer")
          p->DomBindings.setInnerHTML("&nbsp;")
        } else {
          p->DomBindings.setTextContent(content)
        }
        Some(p)
      }
    }

  | Divider(_) => {
      let hr = DomBindings.document->DomBindings.createElement("hr")
      hr->DomBindings.setClassName("wf-divider")
      Some(hr)
    }

  | Row({children, align}) => {
      let row = DomBindings.document->DomBindings.createElement("div")
      row->DomBindings.setClassName("wf-row")
      applyAlignment(row, align)

      children->Array.forEach(child => {
        switch renderElement(child, ~onAction?, ~onDeadEnd?) {
        | Some(el) => row->DomBindings.appendChild(el)
        | None => ()
        }
      })

      Some(row)
    }

  | Section({name, children}) => {
      let section = DomBindings.document->DomBindings.createElement("div")
      section->DomBindings.setClassName("wf-section")

      let header = DomBindings.document->DomBindings.createElement("div")
      header->DomBindings.setClassName("wf-section-header")
      header->DomBindings.setTextContent(name)

      let contentEl = DomBindings.document->DomBindings.createElement("div")
      contentEl->DomBindings.setClassName("wf-section-content")

      children->Array.forEach(child => {
        switch renderElement(child, ~onAction?, ~onDeadEnd?) {
        | Some(el) => contentEl->DomBindings.appendChild(el)
        | None => ()
        }
      })

      section->DomBindings.appendChild(header)
      section->DomBindings.appendChild(contentEl)
      Some(section)
    }
    }
  }
}

let renderScene = (
  scene: scene,
  ~onAction: option<actionHandler>=?,
  ~onDeadEnd: option<deadEndHandler>=?,
): DomBindings.element => {
  let sceneEl = DomBindings.document->DomBindings.createElement("div")
  sceneEl->DomBindings.setClassName("wf-scene")
  sceneEl->DomBindings.dataset->DomBindings.setDataAttr("scene", scene.id)

  scene.elements->Array.forEach(elem => {
    switch renderElement(elem, ~onAction?, ~onDeadEnd?) {
    | Some(el) => sceneEl->DomBindings.appendChild(el)
    | None => ()
    }
  })

  sceneEl
}

// ============================================================================
// Scene Manager Implementation
// ============================================================================

let createSceneManager = (
  scenes: Map.t<string, DomBindings.element>,
  ~onSceneChange: option<onSceneChangeCallback>=?,
): sceneManager => {
  let currentScene = ref(None)
  let historyStack: ref<array<string>> = ref([])
  let forwardStack: ref<array<string>> = ref([])

  // Helper to call onSceneChange callback if provided
  let notifySceneChange = (fromScene: option<string>, toScene: string): unit => {
    switch onSceneChange {
    | Some(callback) => callback(fromScene, toScene)
    | None => ()
    }
  }

  // Internal function to switch scenes without affecting history
  let switchToScene = (id: string, ~notify: bool=true): unit => {
    let previousScene = currentScene.contents

    switch previousScene {
    | Some(currentId) => {
        switch scenes->Map.get(currentId) {
        | Some(el) => el->DomBindings.classList->DomBindings.remove("active")
        | None => ()
        }
      }
    | None => ()
    }

    switch scenes->Map.get(id) {
    | Some(el) => {
        el->DomBindings.classList->DomBindings.add("active")
        currentScene := Some(id)
        // Notify callback if enabled and scene actually changed
        if notify {
          switch previousScene {
          | Some(prevId) if prevId == id => () // Same scene, no notification
          | _ => notifySceneChange(previousScene, id)
          }
        }
      }
    | None => ()
    }
  }

  let goto = (id: string): unit => {
    // Add current scene to history before navigating
    switch currentScene.contents {
    | Some(currentId) if currentId != id => {
        historyStack := historyStack.contents->Array.concat([currentId])
        // Clear forward stack when navigating to new scene
        forwardStack := []
      }
    | _ => ()
    }
    switchToScene(id)
  }

  let back = (): unit => {
    let history = historyStack.contents
    let len = history->Array.length
    if len > 0 {
      switch history->Array.get(len - 1) {
      | Some(prevId) => {
          // Add current scene to forward stack
          switch currentScene.contents {
          | Some(currentId) => {
              forwardStack := forwardStack.contents->Array.concat([currentId])
            }
          | None => ()
          }
          // Remove last item from history
          historyStack := history->Array.slice(~start=0, ~end=len - 1)
          // Navigate to previous scene
          switchToScene(prevId)
        }
      | None => ()
      }
    }
  }

  let forward = (): unit => {
    let fwdStack = forwardStack.contents
    let len = fwdStack->Array.length
    if len > 0 {
      switch fwdStack->Array.get(len - 1) {
      | Some(nextId) => {
          // Add current scene to history
          switch currentScene.contents {
          | Some(currentId) => {
              historyStack := historyStack.contents->Array.concat([currentId])
            }
          | None => ()
          }
          // Remove last item from forward stack
          forwardStack := fwdStack->Array.slice(~start=0, ~end=len - 1)
          // Navigate to next scene
          switchToScene(nextId)
        }
      | None => ()
      }
    }
  }

  let refresh = (): unit => {
    switch currentScene.contents {
    | Some(id) => {
        // Remove active class and re-add it to trigger any CSS animations
        switch scenes->Map.get(id) {
        | Some(el) => {
            el->DomBindings.classList->DomBindings.remove("active")
            // Use setTimeout to ensure the class removal is processed
            let _ = Js.Global.setTimeout(() => {
              el->DomBindings.classList->DomBindings.add("active")
            }, 0)
          }
        | None => ()
        }
      }
    | None => ()
    }
  }

  let canGoBack = (): bool => historyStack.contents->Array.length > 0

  let canGoForward = (): bool => forwardStack.contents->Array.length > 0

  let getCurrentScene = (): option<string> => currentScene.contents

  let getSceneIds = (): array<string> => {
    scenes->Map.keys->Iterator.toArray
  }

  {
    goto,
    back,
    forward,
    refresh,
    canGoBack,
    canGoForward,
    getCurrentScene,
    getSceneIds,
  }
}

// ============================================================================
// Style Injection
// ============================================================================

let injectStyles = (): unit => {
  switch DomBindings.document->DomBindings.getElementById("wf-styles")->Nullable.toOption {
  | Some(_) => ()
  | None => {
      let style = DomBindings.document->DomBindings.createElement("style")
      style->DomBindings.setId("wf-styles")
      style->DomBindings.setTextContent(defaultStyles)
      DomBindings.document->DomBindings.head->DomBindings.appendChild(style)
    }
  }
}

// ============================================================================
// Main Render Function
// ============================================================================

@genType
let render = (ast: ast, options: option<renderOptions>): renderResult => {
  let opts = options->Option.getOr(defaultOptions)

  if opts.injectStyles {
    injectStyles()
  }

  let app = DomBindings.document->DomBindings.createElement("div")
  app->DomBindings.setClassName("wf-app")

  switch opts.containerClass {
  | Some(cls) => app->DomBindings.classList->DomBindings.add(cls)
  | None => ()
  }

  // Apply device class based on options.device override or first scene's device type
  let deviceType = switch opts.device {
  | Some(device) => Some(device)
  | None =>
    switch ast.scenes->Array.get(0) {
    | Some(firstScene) => Some(firstScene.device)
    | None => None
    }
  }

  switch deviceType {
  | Some(device) => {
      let deviceClass = deviceTypeToClass(device)
      app->DomBindings.classList->DomBindings.add(deviceClass)
    }
  | None => ()
  }

  // Create refs to hold navigation functions (set after sceneManager is created)
  let gotoRef: ref<option<string => unit>> = ref(None)
  let backRef: ref<option<unit => unit>> = ref(None)
  let forwardRef: ref<option<unit => unit>> = ref(None)

  // Create action handler that uses the refs
  let handleAction = (action: interactionAction): unit => {
    switch action {
    | Goto({target, _}) => {
        switch gotoRef.contents {
        | Some(goto) => goto(target)
        | None => ()
        }
      }
    | Back => {
        switch backRef.contents {
        | Some(back) => back()
        | None => ()
        }
      }
    | Forward => {
        switch forwardRef.contents {
        | Some(forward) => forward()
        | None => ()
        }
      }
    | Validate(_) => {
        // TODO: Implement field validation
        ()
      }
    | Call(_) => {
        // TODO: Implement custom function calls
        ()
      }
    }
  }

  let sceneMap = Map.make()

  ast.scenes->Array.forEach(scene => {
    // Create a scene-specific dead end handler that includes the scene ID
    let handleDeadEnd = switch opts.onDeadEndClick {
    | Some(callback) =>
      Some((elementId: string, elementText: string, elementType: [#button | #link]) => {
        callback({
          sceneId: scene.id,
          elementId,
          elementText,
          elementType,
        })
      })
    | None => None
    }

    let sceneEl = renderScene(scene, ~onAction=handleAction, ~onDeadEnd=?handleDeadEnd)
    app->DomBindings.appendChild(sceneEl)
    sceneMap->Map.set(scene.id, sceneEl)
  })

  let manager = createSceneManager(sceneMap, ~onSceneChange=?opts.onSceneChange)

  // Now that sceneManager is created, set the refs
  gotoRef := Some(manager.goto)
  backRef := Some(manager.back)
  forwardRef := Some(manager.forward)

  if ast.scenes->Array.length > 0 {
    switch ast.scenes->Array.get(0) {
    | Some(firstScene) => manager.goto(firstScene.id)
    | None => ()
    }
  }

  {
    root: app,
    sceneManager: manager,
  }
}

@genType
let toHTMLString = (_ast: ast, _options: option<renderOptions>): string => {
  "<!-- Static HTML generation not yet implemented -->"
}

// ============================================================================
// createUI - Convenience Functions
// ============================================================================

/**
 * Result type for createUI function.
 * Contains either success with rendered elements or error with parse errors.
 */
type createUISuccessResult = {
  root: DomBindings.element,
  sceneManager: sceneManager,
  ast: Types.ast,
  warnings: array<ErrorTypes.t>,
}

type createUIResult = result<createUISuccessResult, array<ErrorTypes.t>>

/**
 * Parse and render wireframe in one step.
 * Combines Parser.parse() and Renderer.render() for convenience.
 *
 * @param text Text containing ASCII wireframe and/or interaction DSL
 * @param options Optional render options
 * @returns Result containing root element, scene manager, and AST, or errors
 *
 * @example
 * ```rescript
 * let result = Renderer.createUI(wireframeText, None)
 * switch result {
 * | Ok({root, sceneManager, ast}) => {
 *     // Append root to DOM
 *     sceneManager.goto("login")
 *   }
 * | Error(errors) => Console.error(errors)
 * }
 * ```
 */
@genType
let createUI = (text: string, options: option<renderOptions>): createUIResult => {
  switch Parser.parse(text) {
  | Ok((ast, warnings)) => {
      let {root, sceneManager} = render(ast, options)
      Ok({root, sceneManager, ast, warnings})
    }
  | Error(errors) => Error(errors)
  }
}

/**
 * Parse and render wireframe, throwing on error.
 * Use this for simpler code when parsing is expected to succeed.
 *
 * @param text Text containing ASCII wireframe and/or interaction DSL
 * @param options Optional render options
 * @returns Rendered root element, scene manager, and AST
 * @raises Js.Exn.Error if parsing fails
 *
 * @example
 * ```rescript
 * let {root, sceneManager, ast} = Renderer.createUIOrThrow(wireframeText, None)
 * // Use root directly - errors will throw exception
 * ```
 */
@genType
let createUIOrThrow = (text: string, options: option<renderOptions>): createUISuccessResult => {
  switch Parser.parse(text) {
  | Ok((ast, warnings)) => {
      let {root, sceneManager} = render(ast, options)
      {root, sceneManager, ast, warnings}
    }
  | Error(errors) => {
      let messages = errors
        ->Array.map(err => ErrorMessages.getTitle(err.code))
        ->Array.join("\n")
      JsError.throwWithMessage("Parse failed:\n" ++ messages)
    }
  }
}

