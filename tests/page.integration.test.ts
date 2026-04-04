import { describe, expect, it } from "vitest";
import fs from "node:fs";
import path from "node:path";
import { JSDOM } from "jsdom";
import { injectAliasesIntoHtml } from "../src/injectAliases";

const projectRoot = process.cwd();
const canonicalUrl = "https://aliases.sh/";
const title = "aliases.sh | curated bash aliases for Git and npm";
const ogImageUrl = "https://aliases.sh/og/aliases-sh.png";
const ogImageAlt =
  "Preview of the aliases.sh bash aliases file with syntax highlighting.";

describe("aliases page integration", () => {
  it("renders the real aliases file as a single static highlighted code block", () => {
    const indexHtml = fs.readFileSync(path.join(projectRoot, "index.html"), "utf-8");
    const aliasesContent = fs.readFileSync(
      path.join(projectRoot, "aliases.sh"),
      "utf-8"
    );
    const renderedHtml = injectAliasesIntoHtml(indexHtml, aliasesContent);
    const dom = new JSDOM(renderedHtml, {
      url: canonicalUrl,
    });

    expect(dom.window.document.querySelectorAll('script[type="application/ld+json"]')).toHaveLength(1);
    expect(dom.window.document.querySelectorAll("script")).toHaveLength(1);
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

  it("ships canonical, social, and WebSite metadata for the home page", () => {
    const indexHtml = fs.readFileSync(path.join(projectRoot, "index.html"), "utf-8");
    const aliasesContent = fs.readFileSync(
      path.join(projectRoot, "aliases.sh"),
      "utf-8"
    );
    const renderedHtml = injectAliasesIntoHtml(indexHtml, aliasesContent);
    const dom = new JSDOM(renderedHtml, {
      url: canonicalUrl,
    });

    expect(dom.window.document.documentElement.lang).toBe("en");
    expect(dom.window.document.title).toBe(title);
    expect(
      dom.window.document.querySelectorAll('link[rel="canonical"]')
    ).toHaveLength(1);
    expect(
      dom.window.document.querySelector('link[rel="canonical"]')?.getAttribute("href")
    ).toBe(canonicalUrl);
    expect(dom.window.document.querySelector('meta[name="keywords"]')).toBeNull();
    expect(
      dom.window.document
        .querySelector('meta[property="og:type"]')
        ?.getAttribute("content")
    ).toBe("website");
    expect(
      dom.window.document
        .querySelector('meta[property="og:site_name"]')
        ?.getAttribute("content")
    ).toBe("aliases.sh");
    expect(
      dom.window.document
        .querySelector('meta[property="og:image"]')
        ?.getAttribute("content")
    ).toBe(ogImageUrl);
    expect(
      dom.window.document
        .querySelector('meta[property="og:image:alt"]')
        ?.getAttribute("content")
    ).toBe(ogImageAlt);
    expect(
      dom.window.document
        .querySelector('meta[name="twitter:card"]')
        ?.getAttribute("content")
    ).toBe("summary_large_image");
    expect(
      dom.window.document
        .querySelector('meta[name="twitter:image"]')
        ?.getAttribute("content")
    ).toBe(ogImageUrl);
    expect(
      dom.window.document
        .querySelector('meta[name="twitter:image:alt"]')
        ?.getAttribute("content")
    ).toBe(ogImageAlt);

    const structuredDataScripts = dom.window.document.querySelectorAll(
      'script[type="application/ld+json"]'
    );
    expect(structuredDataScripts).toHaveLength(1);

    const structuredData = JSON.parse(structuredDataScripts[0].textContent ?? "");
    expect(structuredData["@type"]).toBe("WebSite");
    expect(structuredData.name).toBe("aliases.sh");
    expect(structuredData.url).toBe(canonicalUrl);
  });
});
