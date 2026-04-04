import { JSDOM } from "jsdom";
import { describe, expect, it, vi } from "vitest";
import {
  getAliasesText,
  handleSelectAllShortcut,
  highlightAliasesCodeBlocks,
} from "../src/page";

const createPageDom = (aliasesContent: string): JSDOM => {
  return new JSDOM(
    `<!DOCTYPE html><html><body><pre><code class="language-bash">${aliasesContent}</code></pre></body></html>`,
    {
      url: "https://aliases.sh/",
    }
  );
};

describe("highlightAliasesCodeBlocks", () => {
  it("highlights the aliases code block", () => {
    const dom = createPageDom("alias gs='git status'");
    const highlighter = {
      highlightElement: vi.fn(),
    };

    highlightAliasesCodeBlocks(dom.window.document, highlighter);

    expect(highlighter.highlightElement).toHaveBeenCalledTimes(1);
    expect(highlighter.highlightElement).toHaveBeenCalledWith(
      dom.window.document.querySelector("pre code")
    );
  });
});

describe("handleSelectAllShortcut", () => {
  it("selects only the aliases text for ctrl+a", () => {
    const aliasesContent = "alias gs='git status'\nalias ga='git add .'";
    const dom = createPageDom(aliasesContent);
    const event = new dom.window.KeyboardEvent("keydown", {
      bubbles: true,
      cancelable: true,
      ctrlKey: true,
      key: "a",
    });

    handleSelectAllShortcut(event, dom.window.document, dom.window);

    expect(dom.window.getSelection()?.toString()).toBe(aliasesContent);
    expect(event.defaultPrevented).toBe(true);
    expect(getAliasesText(dom.window.document)).toBe(aliasesContent);
  });

  it("does not override ctrl+a inside editable inputs", () => {
    const dom = createPageDom("alias gs='git status'");
    const input = dom.window.document.createElement("input");
    dom.window.document.body.appendChild(input);
    input.focus();

    const event = new dom.window.KeyboardEvent("keydown", {
      bubbles: true,
      cancelable: true,
      ctrlKey: true,
      key: "a",
    });

    handleSelectAllShortcut(event, dom.window.document, dom.window);

    expect(dom.window.getSelection()?.toString()).toBe("");
    expect(event.defaultPrevented).toBe(false);
  });
});
