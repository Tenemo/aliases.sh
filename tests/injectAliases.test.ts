import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  ALIASES_PLACEHOLDER,
  HIGHLIGHT_THEME_PLACEHOLDER,
  RAW_ALIASES_FILE_NAME,
  createInjectAliasesPlugin,
  highlightAliasesContent,
  injectAliasesIntoHtml,
  renderRawAliasesAsset,
} from "../src/injectAliases";

const temporaryRoots: string[] = [];

afterEach(() => {
  while (temporaryRoots.length > 0) {
    const temporaryRoot = temporaryRoots.pop();

    if (temporaryRoot) {
      fs.rmSync(temporaryRoot, {
        force: true,
        recursive: true,
      });
    }
  }
});

const createTemporaryRoot = (): string => {
  const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), "raw-aliases-test-"));
  temporaryRoots.push(temporaryRoot);
  return temporaryRoot;
};

describe("injectAliasesIntoHtml", () => {
  it("injects highlighted aliases content and inline theme CSS into the page template", () => {
    const html = `<style>${HIGHLIGHT_THEME_PLACEHOLDER}</style><body>${ALIASES_PLACEHOLDER}</body>`;
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
    expect(renderedHtml).not.toContain(ALIASES_PLACEHOLDER);
  });

  it("fails if the aliases placeholder appears more than once", () => {
    const html = `<body>${ALIASES_PLACEHOLDER}${ALIASES_PLACEHOLDER}</body><style>${HIGHLIGHT_THEME_PLACEHOLDER}</style>`;

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

describe("raw aliases asset", () => {
  it("keeps the raw aliases content unchanged", () => {
    const aliasesContent = `# https://github.com/Tenemo/aliases.sh\nalias ll='ls -l'\n`;

    expect(renderRawAliasesAsset(aliasesContent)).toBe(aliasesContent);
  });

  it("emits the raw aliases content at the extensionless raw path", () => {
    const temporaryRoot = createTemporaryRoot();
    const aliasesContent = `# https://github.com/Tenemo/aliases.sh\nalias ll='ls -l'\n`;
    const emittedFiles: unknown[] = [];

    fs.writeFileSync(path.join(temporaryRoot, "aliases.sh"), aliasesContent);

    const plugin = createInjectAliasesPlugin(temporaryRoot);
    const generateBundle = plugin.generateBundle;

    expect(typeof generateBundle).toBe("function");
    if (typeof generateBundle !== "function") {
      throw new Error("Expected raw aliases plugin to define generateBundle.");
    }

    (
      generateBundle as unknown as (
        this: {
          emitFile: (emittedFile: unknown) => string;
        },
        bundle: unknown,
        writeBundle: boolean
      ) => void
    ).call(
      {
        emitFile(emittedFile: unknown): string {
          emittedFiles.push(emittedFile);
          return "raw-aliases";
        },
      },
      {},
      false
    );

    expect(emittedFiles).toContainEqual({
      type: "asset",
      fileName: RAW_ALIASES_FILE_NAME,
      source: aliasesContent,
    });
  });
});
