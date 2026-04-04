import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import hljs from "highlight.js/lib/core";
import bash from "highlight.js/lib/languages/bash";
import type { Plugin } from "vite";

export const ALIASES_PLACEHOLDER = "<!-- __ALIASES_CONTENT__ -->";
export const HIGHLIGHT_THEME_PLACEHOLDER = "/* __INLINE_HLJS_THEME__ */";

const require = createRequire(import.meta.url);
const highlightThemePath = require.resolve("highlight.js/styles/a11y-dark.css");

hljs.registerLanguage("bash", bash);

const replaceUniquePlaceholder = (
  html: string,
  placeholder: string,
  replacement: string,
  label: string
): string => {
  const occurrences = html.split(placeholder).length - 1;

  if (occurrences !== 1) {
    throw new Error(
      `Expected exactly one ${label} placeholder, found ${occurrences}.`
    );
  }

  return html.replace(placeholder, () => replacement);
};

export const highlightAliasesContent = (aliasesContent: string): string => {
  return hljs.highlight(aliasesContent, {
    language: "bash",
    ignoreIllegals: true,
  }).value;
};

export const renderAliasesBlock = (aliasesContent: string): string => {
  return `<pre><code class="hljs language-bash">${highlightAliasesContent(
    aliasesContent
  )}</code></pre>`;
};

export const readHighlightThemeCss = (): string => {
  return fs.readFileSync(highlightThemePath, "utf-8");
};

export const injectAliasesIntoHtml = (
  html: string,
  aliasesContent: string,
  highlightThemeCss: string = readHighlightThemeCss()
): string => {
  const htmlWithAliases = replaceUniquePlaceholder(
    html,
    ALIASES_PLACEHOLDER,
    renderAliasesBlock(aliasesContent),
    "aliases"
  );

  return replaceUniquePlaceholder(
    htmlWithAliases,
    HIGHLIGHT_THEME_PLACEHOLDER,
    highlightThemeCss,
    "highlight theme"
  );
};

const getAliasesFilePath = (rootDir: string): string => {
  return path.resolve(rootDir, "aliases.sh");
};

const readAliasesFile = (rootDir: string): string => {
  return fs.readFileSync(getAliasesFilePath(rootDir), "utf-8");
};

export const createInjectAliasesPlugin = (rootDir: string): Plugin => {
  return {
    name: "inject-aliases",
    transformIndexHtml(html: string): string {
      return injectAliasesIntoHtml(html, readAliasesFile(rootDir));
    },
  };
};
