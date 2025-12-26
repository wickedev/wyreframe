// MultiSceneNavigation_test.res
// Regression test for Issue #15: Scene transition fails from following to fullview scene
//
// This test verifies that buttons with navigation actions in multi-scene wireframes
// correctly have their actions attached after parsing and merging.

open Vitest
open Types

describe("Issue #15: Multi-scene navigation", () => {
  // Simplified wireframe from the issue - following scene with View Profile button
  let multiSceneWireframe = `@scene: profile

+---------------------------------------+
|                                       |
|              'John Doe'               |
|                                       |
|       [ Follow ] [ Message ]          |
|                                       |
+---------------------------------------+

[Follow]:
  variant: primary
  @click -> goto(following, fade)

[Message]:
  variant: outline
  @click -> goto(message, slide-left)

---

@scene: following

+---------------------------------------+
|                                       |
|          'Following John'             |
|                                       |
|      [ View Profile ] [ Done ]        |
|                                       |
+---------------------------------------+

[View Profile]:
  variant: outline
  @click -> goto(fullview, slide-right)

[Done]:
  variant: primary
  @click -> goto(profile, fade)

---

@scene: fullview

+---------------------------------------+
|                                       |
|              'Full View'              |
|                                       |
|            [ Back ]                   |
|                                       |
+---------------------------------------+

[Back]:
  variant: ghost
  @click -> goto(following, slide-left)
`

  describe("Parser correctly extracts interactions for all scenes", () => {
    test("parses all three scenes", t => {
      let result = Parser.parse(multiSceneWireframe)

      switch result {
      | Ok((ast, _warnings)) => {
          t->expect(ast.scenes->Array.length)->Expect.toBe(3)

          // Verify scene IDs
          let sceneIds = ast.scenes->Array.map(scene => scene.id)
          t->expect(sceneIds->Array.includes("profile"))->Expect.toBe(true)
          t->expect(sceneIds->Array.includes("following"))->Expect.toBe(true)
          t->expect(sceneIds->Array.includes("fullview"))->Expect.toBe(true)
        }
      | Error(errors) => {
          Console.error2("Parse errors:", errors)
          t->expect(true)->Expect.toBe(false)
        }
      }
    })

    test("following scene has View Profile button with navigation action", t => {
      let result = Parser.parse(multiSceneWireframe)

      switch result {
      | Ok((ast, _warnings)) => {
          // Find the following scene
          let followingScene = ast.scenes->Array.find(scene => scene.id === "following")

          switch followingScene {
          | Some(scene) => {
              // Find View Profile button - it should be in a Row element
              let viewProfileButton = scene.elements->Array.findMap(elem => {
                switch elem {
                | Row({children, _}) =>
                  children->Array.findMap(child => {
                    switch child {
                    | Button({id, text, actions, _}) if id === "view-profile" =>
                      Some((id, text, actions))
                    | _ => None
                    }
                  })
                | Button({id, text, actions, _}) if id === "view-profile" =>
                  Some((id, text, actions))
                | _ => None
                }
              })

              switch viewProfileButton {
              | Some((_id, _text, actions)) => {
                  // This is the critical check - the button should have navigation actions
                  t->expect(actions->Array.length)->Expect.Int.toBeGreaterThan(0)

                  // Verify it's a Goto action to fullview
                  switch actions->Array.get(0) {
                  | Some(Goto({target, _})) => {
                      t->expect(target)->Expect.toBe("fullview")
                    }
                  | _ => {
                      t->expect(true)->Expect.toBe(false) // Expected Goto action
                    }
                  }
                }
              | None => {
                  t->expect(true)->Expect.toBe(false) // View Profile button not found
                }
              }
            }
          | None => {
              t->expect(true)->Expect.toBe(false) // Following scene not found
            }
          }
        }
      | Error(_errors) => {
          t->expect(true)->Expect.toBe(false) // Parse failed
        }
      }
    })

    test("hasNavigationAction returns true for View Profile button actions", t => {
      let result = Parser.parse(multiSceneWireframe)

      switch result {
      | Ok((ast, _warnings)) => {
          // Find the following scene
          let followingScene = ast.scenes->Array.find(scene => scene.id === "following")

          switch followingScene {
          | Some(scene) => {
              // Find the View Profile button's actions
              let viewProfileActions = scene.elements->Array.findMap(elem => {
                switch elem {
                | Row({children, _}) =>
                  children->Array.findMap(child => {
                    switch child {
                    | Button({id, actions, _}) if id === "view-profile" => Some(actions)
                    | _ => None
                    }
                  })
                | Button({id, actions, _}) if id === "view-profile" => Some(actions)
                | _ => None
                }
              })

              switch viewProfileActions {
              | Some(actions) => {
                  // The button should have navigation actions
                  let hasNav = Renderer.hasNavigationAction(actions)
                  t->expect(hasNav)->Expect.toBe(true)
                }
              | None => {
                  t->expect(true)->Expect.toBe(false)
                }
              }
            }
          | None => {
              t->expect(true)->Expect.toBe(false)
            }
          }
        }
      | Error(_) => {
          t->expect(true)->Expect.toBe(false)
        }
      }
    })
  })

  describe("TextExtractor correctly handles multi-scene interactions", () => {
    test("extracts scene headers for each scene's interactions", t => {
      let extracted = TextExtractor.extract(multiSceneWireframe)

      // The interactions should contain scene headers for each scene
      let interactions = extracted.interactions

      // Check that following scene interactions are included
      t->expect(interactions->String.includes("@scene: following"))->Expect.toBe(true)

      // Check that the View Profile interaction is associated with following scene
      t->expect(interactions->String.includes("[View Profile]:"))->Expect.toBe(true)
    })
  })

  describe("SimpleInteractionParser correctly parses multi-scene interactions", () => {
    test("parses interactions for following scene correctly", t => {
      let extracted = TextExtractor.extract(multiSceneWireframe)
      let parseResult = InteractionParser.parse(extracted.interactions)

      switch parseResult {
      | Ok(sceneInteractions) => {
          // Find interactions for the following scene
          let followingInteractions = sceneInteractions->Array.find(si =>
            si.sceneId === "following"
          )

          switch followingInteractions {
          | Some(si) => {
              // Find the view-profile interaction
              let viewProfileInteraction = si.interactions->Array.find(i =>
                i.elementId === "view-profile"
              )

              switch viewProfileInteraction {
              | Some(interaction) => {
                  t->expect(interaction.actions->Array.length)->Expect.Int.toBeGreaterThan(0)

                  switch interaction.actions->Array.get(0) {
                  | Some(Goto({target, _})) => {
                      t->expect(target)->Expect.toBe("fullview")
                    }
                  | _ => {
                      Console.error("Expected Goto action")
                      t->expect(true)->Expect.toBe(false)
                    }
                  }
                }
              | None => {
                  Console.error("view-profile interaction not found")
                  Console.log2("Following scene interactions:", si.interactions)
                  t->expect(true)->Expect.toBe(false)
                }
              }
            }
          | None => {
              Console.error("Following scene interactions not found")
              Console.log2("All scene interactions:", sceneInteractions)
              t->expect(true)->Expect.toBe(false)
            }
          }
        }
      | Error(err) => {
          Console.error2("Parse error:", err)
          t->expect(true)->Expect.toBe(false)
        }
      }
    })
  })
})
