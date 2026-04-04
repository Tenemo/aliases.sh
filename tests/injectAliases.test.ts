import { describe, expect, it } from "vitest";
import {
  ALIASES_TEMPLATE,
  escapeHtml,
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
  it("injects escaped aliases content into the page template", () => {
    const html = `<body>${ALIASES_TEMPLATE}</body>`;
    const renderedHtml = injectAliasesIntoHtml(
      html,
      `alias ll='ls -la && echo "<done>"'`
    );

    expect(renderedHtml).toContain(
      "alias ll=&#039;ls -la &amp;&amp; echo &quot;&lt;done&gt;&quot;&#039;"
    );
    expect(renderedHtml).not.toContain(ALIASES_TEMPLATE);
  });
});
