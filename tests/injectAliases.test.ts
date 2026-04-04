import { describe, expect, it } from "vitest";
import {
  ALIASES_TEMPLATE,
  escapeHtml,
  HIGHLIGHT_THEME_PLACEHOLDER,
  highlightAliasesContent,
  injectAliasesIntoHtml,
} from "../src/injectAliases";

describe("escapeHtml", () => {
  it("escapes HTML-sensitive characters in aliases content", () => {
    expect(escapeHtml(`alias test='echo "<&>"'`)).toBe(
      "alias test=&#039;echo &quot;&lt;&amp;&gt;&quot;&#039;"
    );
  });
});

describe("injectAliasesIntoHtml", () => {
  it("injects highlighted aliases content and inline theme CSS into the page template", () => {
    const html = `<style>${HIGHLIGHT_THEME_PLACEHOLDER}</style><body>${ALIASES_TEMPLATE}</body>`;
    const renderedHtml = injectAliasesIntoHtml(
      html,
      `alias ll='ls -la && echo "<done>"'`,
      ".hljs { color: red; }"
    );

    expect(renderedHtml).toContain(".hljs { color: red; }");
    expect(renderedHtml).toContain('class="hljs language-bash"');
    expect(renderedHtml).toContain("<span");
    expect(renderedHtml).toContain("&lt;done&gt;");
    expect(renderedHtml).not.toContain(HIGHLIGHT_THEME_PLACEHOLDER);
    expect(renderedHtml).toContain('<span class="hljs-built_in">alias</span>');
    expect(renderedHtml).not.toContain(ALIASES_TEMPLATE);
  });

  it("fails if the aliases placeholder appears more than once", () => {
    const html = `<body>${ALIASES_TEMPLATE}${ALIASES_TEMPLATE}</body><style>${HIGHLIGHT_THEME_PLACEHOLDER}</style>`;

    expect(() => injectAliasesIntoHtml(html, "alias ll='ls -l'", ".hljs {}")).toThrow(
      /aliases placeholder/
    );
  });
});

describe("highlightAliasesContent", () => {
  it("returns escaped tokenized markup for bash content", () => {
    const highlighted = highlightAliasesContent(`alias ll='echo "<done>"'`);

    expect(highlighted).toContain("<span");
    expect(highlighted).toContain("&lt;done&gt;");
  });
});
