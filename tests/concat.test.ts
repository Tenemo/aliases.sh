import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";
import { afterEach, describe, expect, it } from "vitest";

const projectRoot = process.cwd();
const tempRoots: string[] = [];
const fileTreeHeading = "// === FILE TREE (PRUNED) ===\n";
const excludedDirsHeading =
  "// === EXCLUDED DIRECTORIES (EXISTENCE ONLY; NOT SCANNED) ===\n";
const excludedFilesHeading =
  "// === EXCLUDED FILES (NAMES ONLY; OUTSIDE PRUNED DIRS) ===\n";
const includedContentsHeading = "// === INCLUDED FILE CONTENTS ===\n";

const resolveBashExecutable = (): string => {
  if (process.platform !== "win32") {
    return "bash";
  }

  const candidates = [
    process.env.GIT_BASH_PATH,
    "C:\\Program Files\\Git\\bin\\bash.exe",
    "C:\\Program Files\\Git\\usr\\bin\\bash.exe",
    "C:\\Program Files (x86)\\Git\\bin\\bash.exe",
    "C:\\Program Files (x86)\\Git\\usr\\bin\\bash.exe",
  ].filter((candidate): candidate is string => Boolean(candidate));

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  try {
    const whereOutput = execFileSync("where.exe", ["bash"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      windowsHide: true,
    });
    const discovered = whereOutput
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean)
      .find((line) => !/\\system32\\bash\.exe$/i.test(line));

    if (discovered) {
      return discovered;
    }
  } catch {
    // Fall through to the explicit error below.
  }

  throw new Error(
    "Git Bash is required to run concat tests on Windows. Set GIT_BASH_PATH if it is installed in a non-standard location."
  );
};

const bashExecutable = resolveBashExecutable();

const createTempRoot = (): string => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "concat-test-"));
  tempRoots.push(tempRoot);
  return tempRoot;
};

const writeTextFile = (rootDir: string, relativePath: string, contents: string): void => {
  const absolutePath = path.join(rootDir, relativePath);
  fs.mkdirSync(path.dirname(absolutePath), {
    recursive: true,
  });
  fs.writeFileSync(absolutePath, contents, "utf8");
};

const writeBinaryFile = (rootDir: string, relativePath: string, contents: Buffer): void => {
  const absolutePath = path.join(rootDir, relativePath);
  fs.mkdirSync(path.dirname(absolutePath), {
    recursive: true,
  });
  fs.writeFileSync(absolutePath, contents);
};

type ConcatRunResult = {
  output: string | null;
  outputPath: string;
  status: number | null;
  stderr: string;
  stdout: string;
};

const concatRunnerScript = `
set -uo pipefail

normalize_path() {
  local input_path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$input_path"
  else
    printf '%s' "$input_path"
  fi
}

PROJECT_ROOT="$(normalize_path "$PROJECT_ROOT_PATH")"
TARGET_ROOT="$(normalize_path "$TARGET_ROOT_PATH")"

cd "$TARGET_ROOT"
source "$PROJECT_ROOT/aliases.sh"
concat "$CONCAT_ARG"
`;

const runConcat = (targetRoot: string, concatArg = "."): ConcatRunResult => {
  const result = spawnSync(bashExecutable, ["-lc", concatRunnerScript], {
    encoding: "utf8",
    env: {
      ...process.env,
      CONCAT_ARG: concatArg,
      PROJECT_ROOT_PATH: projectRoot,
      TARGET_ROOT_PATH: targetRoot,
    },
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  });

  if (result.error) {
    throw result.error;
  }

  const outputPath = path.join(targetRoot, "temp.txt");

  return {
    output: fs.existsSync(outputPath) ? fs.readFileSync(outputPath, "utf8") : null,
    outputPath,
    status: result.status,
    stderr: result.stderr,
    stdout: result.stdout,
  };
};

const escapeRegExp = (value: string): string => {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
};

const readSummaryCount = (output: string, label: string): number => {
  const match = output.match(
    new RegExp(`^// ${escapeRegExp(label)}:\\s+(\\d+)$`, "m")
  );

  if (!match) {
    throw new Error(`Missing summary line for "${label}".`);
  }

  return Number(match[1]);
};

const readSection = (
  output: string,
  startHeading: string,
  endHeading?: string
): string => {
  const start = output.indexOf(startHeading);

  if (start === -1) {
    throw new Error(`Missing section heading: ${startHeading.trim()}`);
  }

  const contentStart = start + startHeading.length;
  const contentEnd = endHeading ? output.indexOf(endHeading, contentStart) : output.length;

  if (endHeading && contentEnd === -1) {
    throw new Error(`Missing section heading: ${endHeading.trim()}`);
  }

  return output.slice(contentStart, contentEnd === -1 ? output.length : contentEnd).trimEnd();
};

const readNonEmptyLines = (section: string): string[] => {
  return section
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line) => line.length > 0);
};

const createMixedFixture = (): string => {
  const fixtureRoot = createTempRoot();

  writeTextFile(fixtureRoot, "README.md", "# Fixture README\n");
  writeTextFile(fixtureRoot, ".git/HEAD", "ref: refs/heads/main\n");
  writeTextFile(fixtureRoot, "node_modules/pkg/index.js", "module.exports = 1;\n");
  writeTextFile(fixtureRoot, "nested/node_modules/dep.js", "module.exports = 2;\n");
  writeTextFile(fixtureRoot, "nested/keep.txt", "keep me\n");
  writeTextFile(fixtureRoot, "docs/guide.md", "## Guide\n");
  writeTextFile(fixtureRoot, "docs.schema.json", "{}\n");
  writeTextFile(fixtureRoot, "src/app.js", 'console.log("app");\n');
  writeTextFile(fixtureRoot, "src/empty.txt", "");
  writeTextFile(fixtureRoot, "src/with spaces.md", "spaced file\n");
  writeTextFile(fixtureRoot, "config/.env", "SECRET=1\n");
  writeTextFile(fixtureRoot, "pnpm-lock.yaml", "lockfileVersion: 9\n");
  writeTextFile(fixtureRoot, "temp.txt.tree.tmp", "stale temp artifact\n");
  writeBinaryFile(
    fixtureRoot,
    "assets/logo.png",
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
  );
  writeBinaryFile(
    fixtureRoot,
    "src/binary.txt",
    Buffer.from([0x00, 0x01, 0x02, 0x03, 0x00])
  );
  writeBinaryFile(
    fixtureRoot,
    "big/huge.txt",
    Buffer.alloc(2 * 1024 * 1024 + 1, 0x41)
  );

  return fixtureRoot;
};

afterEach(() => {
  while (tempRoots.length > 0) {
    const tempRoot = tempRoots.pop();

    if (tempRoot) {
      fs.rmSync(tempRoot, {
        force: true,
        recursive: true,
      });
    }
  }
});

describe("concat", () => {
  it("returns exit code 2 when the target directory does not exist", () => {
    const fixtureRoot = createTempRoot();
    const result = runConcat(fixtureRoot, "./missing");

    expect(result.status).toBe(2);
    expect(result.stdout).toBe("");
    expect(result.stderr).toContain("concat: directory not found: ./missing");
    expect(fs.existsSync(result.outputPath)).toBe(false);
  });

  it("produces the expected snapshot sections and exclusions for a mixed fixture", () => {
    const fixtureRoot = createMixedFixture();
    const result = runConcat(fixtureRoot);

    expect(result.status).toBe(0);
    expect(result.stdout).toBe("");
    expect(result.output).not.toBeNull();

    const output = result.output ?? "";
    const treeSection = readSection(output, fileTreeHeading, excludedDirsHeading);
    const excludedDirsSection = readSection(
      output,
      excludedDirsHeading,
      excludedFilesHeading
    );
    const excludedFilesSection = readSection(
      output,
      excludedFilesHeading,
      includedContentsHeading
    );
    const includedContentsSection = readSection(output, includedContentsHeading);

    expect(readSummaryCount(output, "Included files (contents copied)")).toBe(6);
    expect(readSummaryCount(output, "Excluded files (names only)")).toBe(6);
    expect(readSummaryCount(output, "Excluded directories (pruned)")).toBe(3);

    expect(treeSection).toContain("//   .git/  [excluded-dir]");
    expect(treeSection).toContain("//   node_modules/  [excluded-dir]");
    expect(treeSection).toContain("//     node_modules/  [excluded-dir]");
    expect(treeSection).toContain("//   assets/");
    expect(treeSection).toContain("//     logo.png  [excluded]");
    expect(treeSection).toContain("//   big/");
    expect(treeSection).toContain("//     huge.txt  [excluded]");
    expect(treeSection).toContain("//   config/");
    expect(treeSection).toContain("//     .env  [excluded]");
    expect(treeSection).toContain("//   docs/");
    expect(treeSection).toContain("//     guide.md");
    expect(treeSection).toContain("//   docs.schema.json  [excluded]");
    expect(treeSection).toContain("//   nested/");
    expect(treeSection).toContain("//     keep.txt");
    expect(treeSection).toContain("//   README.md");
    expect(treeSection).toContain("//   pnpm-lock.yaml  [excluded]");
    expect(treeSection).toContain("//   src/");
    expect(treeSection).toContain("//     app.js");
    expect(treeSection).toContain("//     binary.txt  [excluded]");
    expect(treeSection).toContain("//     empty.txt");
    expect(treeSection).toContain("//     with spaces.md");
    expect(treeSection).not.toContain("node_modules/pkg/index.js");
    expect(treeSection).not.toContain("nested/node_modules/dep.js");
    expect(treeSection).not.toContain("temp.txt.tree.tmp");

    expect(readNonEmptyLines(excludedDirsSection)).toEqual([
      "// Listed alphabetically.",
      "//   - .git/",
      "//   - nested/node_modules/",
      "//   - node_modules/",
    ]);

    expect(excludedFilesSection.trim()).toBe(
      [
        "// Grouped by extension with counts.",
        "// .env (1):",
        "//   - config/.env",
        "//",
        "// .json (1):",
        "//   - docs.schema.json",
        "//",
        "// .png (1):",
        "//   - assets/logo.png",
        "//",
        "// .txt (2):",
        "//   - big/huge.txt",
        "//   - src/binary.txt",
        "//",
        "// .yaml (1):",
        "//   - pnpm-lock.yaml",
      ].join("\n")
    );

    expect(includedContentsSection).toContain(
      '// Contents of: "README.md"\n# Fixture README\n'
    );
    expect(includedContentsSection).toContain(
      '// Contents of: "docs/guide.md"\n## Guide\n'
    );
    expect(includedContentsSection).toContain(
      '// Contents of: "nested/keep.txt"\nkeep me\n'
    );
    expect(includedContentsSection).toContain(
      '// Contents of: "src/app.js"\nconsole.log("app");\n'
    );
    expect(includedContentsSection).toContain('// Contents of: "src/empty.txt"\n');
    expect(includedContentsSection).toContain(
      '// Contents of: "src/with spaces.md"\nspaced file'
    );
    expect(includedContentsSection).not.toContain('Contents of: "config/.env"');
    expect(includedContentsSection).not.toContain('Contents of: "pnpm-lock.yaml"');
    expect(includedContentsSection).not.toContain('Contents of: "src/binary.txt"');
    expect(includedContentsSection).not.toContain('Contents of: "assets/logo.png"');
    expect(includedContentsSection).not.toContain('Contents of: "big/huge.txt"');
    expect(includedContentsSection).not.toContain("SECRET=1");
    expect(includedContentsSection).not.toContain("stale temp artifact");
    expect(includedContentsSection).not.toContain("module.exports = 1;");
    expect(includedContentsSection).not.toContain("module.exports = 2;");
  });

  it("prunes common generated framework and cache directories", () => {
    const fixtureRoot = createTempRoot();
    const generatedDirectories = [
      ".angular",
      ".next",
      ".netlify",
      ".nuxt",
      ".output",
      ".parcel-cache",
      ".react-router",
      ".svelte-kit",
      ".tmp",
      ".turbo",
      ".vercel",
      "coverage",
      "tmp",
    ];

    writeTextFile(fixtureRoot, "src/app.ts", "export const value = 1;\n");
    for (const directory of generatedDirectories) {
      writeTextFile(fixtureRoot, `${directory}/ignored.js`, "throw new Error('ignore');\n");
    }

    const result = runConcat(fixtureRoot);

    expect(result.status).toBe(0);
    expect(result.output).not.toBeNull();

    const output = result.output ?? "";
    const treeSection = readSection(output, fileTreeHeading, excludedDirsHeading);
    const excludedDirsSection = readSection(
      output,
      excludedDirsHeading,
      excludedFilesHeading
    );

    expect(readSummaryCount(output, "Included files (contents copied)")).toBe(1);
    expect(readSummaryCount(output, "Excluded files (names only)")).toBe(0);
    expect(readSummaryCount(output, "Excluded directories (pruned)")).toBe(
      generatedDirectories.length
    );
    expect(treeSection).toContain("//   src/");
    expect(treeSection).toContain("//     app.ts");
    expect(treeSection).not.toContain("ignored.js");
    expect(readNonEmptyLines(excludedDirsSection)).toEqual([
      "// Listed alphabetically.",
      ...[...generatedDirectories].sort().map((directory) => `//   - ${directory}/`),
    ]);
  });

  it("does not ingest a previous temp.txt snapshot when rerun in the same directory", () => {
    const fixtureRoot = createTempRoot();

    writeTextFile(fixtureRoot, "src/app.js", 'console.log("rerun");\n');

    const firstRun = runConcat(fixtureRoot);
    expect(firstRun.status).toBe(0);
    expect(firstRun.output).not.toBeNull();

    const secondRun = runConcat(fixtureRoot);
    expect(secondRun.status).toBe(0);
    expect(secondRun.output).toBe(firstRun.output);

    const output = secondRun.output ?? "";
    const treeSection = readSection(output, fileTreeHeading, excludedDirsHeading);
    const includedContentsSection = readSection(output, includedContentsHeading);

    expect(readSummaryCount(output, "Included files (contents copied)")).toBe(1);
    expect(treeSection).not.toContain("//   temp.txt");
    expect(treeSection).toContain("//   src/");
    expect(treeSection).toContain("//     app.js");
    expect(includedContentsSection).toContain(
      '// Contents of: "src/app.js"\nconsole.log("rerun");'
    );
    expect(includedContentsSection).not.toContain('Contents of: "temp.txt"');
  });
});
