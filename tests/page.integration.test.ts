import fs from "node:fs";
import path from "node:path";
import { JSDOM } from "jsdom";
import { describe, expect, it, vi } from "vitest";
import { injectAliasesIntoHtml } from "../src/injectAliases";
import { initializeAliasesPage } from "../src/page";

const projectRoot = process.cwd();

describe("aliases page integration", () => {
  it("renders the real aliases file and keeps ctrl+a copy-paste friendly", () => {
    const indexHtml = fs.readFileSync(path.join(projectRoot, "index.html"), "utf-8");
    const aliasesContent = fs.readFileSync(
      path.join(projectRoot, "aliases.sh"),
      "utf-8"
    );
    const renderedHtml = injectAliasesIntoHtml(indexHtml, aliasesContent);
    const dom = new JSDOM(renderedHtml, {
      url: "https://aliases.sh/",
    });
    const highlighter = {
      highlightElement: vi.fn(),
    };

    initializeAliasesPage(dom.window.document, dom.window, highlighter);
    dom.window.document.dispatchEvent(
      new dom.window.KeyboardEvent("keydown", {
        bubbles: true,
        cancelable: true,
        ctrlKey: true,
        key: "a",
      })
    );

    expect(highlighter.highlightElement).toHaveBeenCalledTimes(1);
    expect(
      dom.window.document.querySelector("pre code")?.textContent
    ).toBe(aliasesContent);
    expect(dom.window.getSelection()?.toString()).toBe(aliasesContent);
  });
});
