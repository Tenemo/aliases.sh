import fs from "node:fs";
import path from "node:path";
import type { Plugin } from "vite";

export const ALIASES_TEMPLATE = '<pre><code class="language-bash"></code></pre>';

export const escapeHtml = (content: string): string => {
  return content
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
};

export const injectAliasesIntoHtml = (
  html: string,
  aliasesContent: string
): string => {
  const escapedContent = escapeHtml(aliasesContent);

  return html.replace(ALIASES_TEMPLATE, () => {
    return `<pre><code class="language-bash">${escapedContent}</code></pre>`;
  });
};

export const getAliasesFilePath = (rootDir: string): string => {
  return path.resolve(rootDir, "aliases.sh");
};

export const readAliasesFile = (rootDir: string): string => {
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
