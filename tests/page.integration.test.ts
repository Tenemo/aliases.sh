import fs from "node:fs";
import path from "node:path";
import { JSDOM } from "jsdom";
import { describe, expect, it } from "vitest";
import { injectAliasesIntoHtml } from "../src/injectAliases";

const projectRoot = process.cwd();

describe("aliases page integration", () => {
  it("renders the real aliases file as a single static highlighted code block", () => {
    const indexHtml = fs.readFileSync(path.join(projectRoot, "index.html"), "utf-8");
    const aliasesContent = fs.readFileSync(
      path.join(projectRoot, "aliases.sh"),
      "utf-8"
    );
    const renderedHtml = injectAliasesIntoHtml(indexHtml, aliasesContent);
    const dom = new JSDOM(renderedHtml, {
      url: "https://aliases.sh/",
    });

    expect(dom.window.document.querySelectorAll("script")).toHaveLength(0);
    expect(dom.window.document.body.children).toHaveLength(1);
    expect(dom.window.document.body.firstElementChild?.tagName).toBe("PRE");
    expect(dom.window.document.querySelectorAll("pre code")).toHaveLength(1);
    expect(dom.window.document.querySelector("pre code")?.textContent).toBe(
      aliasesContent
    );
    expect(dom.window.document.querySelector("pre code.hljs")).not.toBeNull();
    expect(dom.window.document.querySelector('pre code span[class^="hljs"]')).not.toBeNull();
    expect(dom.window.document.querySelector("style")?.textContent).toContain(".hljs");
  });
});
