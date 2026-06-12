// DomMode.test.ts
// Smoke test for renderToDOM using a hand-rolled DOM stub.
// We don't pull jsdom in as a dev dependency for this work; the stub
// implements only the surface the V2 DomBuilder touches:
//   document.createElement, document.createTextNode, appendChild,
//   setAttribute, replaceChildren, innerHTML setter.

import { describe, test, expect, beforeEach } from "vitest";
// @ts-ignore — ReScript-generated module
import * as V2Renderer from "../V2Renderer.mjs";
// @ts-ignore
import * as V2Parser from "../../../parser/v2/V2Parser.mjs";

interface StubElement {
  tag: string;
  attrs: Record<string, string>;
  children: Array<StubElement | StubText>;
  innerHTML?: string;
  appendChild: (c: StubElement | StubText) => void;
  setAttribute: (k: string, v: string) => void;
  replaceChildren: () => void;
}

interface StubText {
  textContent: string;
  isText: true;
}

function makeElement(tag: string): StubElement {
  const el: StubElement = {
    tag,
    attrs: {},
    children: [],
    appendChild(c) {
      el.children.push(c);
    },
    setAttribute(k, v) {
      el.attrs[k] = v;
    },
    replaceChildren() {
      el.children = [];
    },
  };
  return el;
}

function makeText(text: string): StubText {
  return { textContent: text, isText: true };
}

function installStubDom() {
  const stub = {
    createElement: (tag: string) => makeElement(tag),
    createTextNode: (s: string) => makeText(s),
  };
  // @ts-ignore — installing onto global for the renderer's @val binding
  globalThis.document = stub;
}

function tagsInTree(node: StubElement | StubText, out: string[]): void {
  if ("isText" in node) {
    return;
  }
  out.push(node.tag);
  for (const c of node.children) {
    tagsInTree(c, out);
  }
}

describe("V2 Renderer DOM mode (stubbed DOM)", () => {
  beforeEach(() => {
    installStubDom();
  });

  test("mounts a simple AST into a container", () => {
    const source = `@scene: home

+--------+
|  [ A ] |
+--------+`;
    const parsed = V2Parser.parse(source);
    const opts = V2Renderer.defaultOptions();
    const container = makeElement("div");

    const handle = V2Renderer.renderToDOM(
      { TAG: parsed.ast.TAG === "SceneBlock" ? "SceneNode" : "ComponentNode", _0: parsed.ast._0 },
      container as unknown as HTMLElement,
      opts
    );

    expect(handle.root).toBe(container);
    expect(Array.isArray(handle.warnings)).toBe(true);
    expect(container.children.length).toBeGreaterThan(0);

    const tags: string[] = [];
    for (const c of container.children) tagsInTree(c, tags);
    expect(tags).toContain("section");
    expect(tags).toContain("button");
  });

  test("update() replaces the existing tree", () => {
    const ast1 = {
      TAG: "ButtonNode",
      _0: {
        location: { start: { row: 0, col: 0, offset: 0 }, end_: { row: 0, col: 0, offset: 0 } },
        id: "a",
        text: "A",
      },
    };
    const ast2 = {
      TAG: "ButtonNode",
      _0: {
        location: { start: { row: 0, col: 0, offset: 0 }, end_: { row: 0, col: 0, offset: 0 } },
        id: "b",
        text: "B",
      },
    };
    const container = makeElement("div");
    const opts = V2Renderer.defaultOptions();
    const handle = V2Renderer.renderToDOM(ast1, container as unknown as HTMLElement, opts);
    expect(container.children.length).toBe(1);
    handle.update(ast2);
    expect(container.children.length).toBe(1);
    const first = container.children[0] as StubElement;
    expect(first.attrs["id"]).toBe("wf-b");
  });

  test("dispose() empties the container", () => {
    const ast = {
      TAG: "ButtonNode",
      _0: {
        location: { start: { row: 0, col: 0, offset: 0 }, end_: { row: 0, col: 0, offset: 0 } },
        id: "a",
        text: "A",
      },
    };
    const container = makeElement("div");
    const opts = V2Renderer.defaultOptions();
    const handle = V2Renderer.renderToDOM(ast, container as unknown as HTMLElement, opts);
    expect(container.children.length).toBe(1);
    handle.dispose();
    expect(container.children.length).toBe(0);
  });
});
