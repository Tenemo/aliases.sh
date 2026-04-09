import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";
import { afterEach, describe, expect, it } from "vitest";

const projectRoot = process.cwd();
const tempRoots: string[] = [];

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
    "Git Bash is required to run git alias tests on Windows. Set GIT_BASH_PATH if it is installed in a non-standard location."
  );
};

const bashExecutable = resolveBashExecutable();

const createTempRoot = (): string => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "git-alias-test-"));
  tempRoots.push(tempRoot);
  return tempRoot;
};

const writeTextFile = (rootDir: string, relativePath: string, contents: string): string => {
  const absolutePath = path.join(rootDir, relativePath);
  fs.mkdirSync(path.dirname(absolutePath), {
    recursive: true,
  });
  fs.writeFileSync(absolutePath, contents, "utf8");
  return absolutePath;
};

type GitAliasRunResult = {
  logLines: string[];
  status: number | null;
  stderr: string;
  stdout: string;
};

const fakeGitScript = `#!/usr/bin/env bash
set -u

log_file="\${FAKE_GIT_LOG:?}"
refs_file="\${FAKE_GIT_REFS_FILE:?}"

has_ref() {
  grep -Fx -- "$1" "$refs_file" >/dev/null 2>&1
}

case "\${1:-}" in
  show-ref)
    if [ "\${2:-}" = "--verify" ] && [ "\${3:-}" = "--quiet" ]; then
      if has_ref "\${4:-}"; then
        exit 0
      fi
      exit 1
    fi
    ;;
  checkout)
    printf 'checkout %s\\n' "\${2:-}" >> "$log_file"
    exit 0
    ;;
  pull)
    printf 'pull %s %s\\n' "\${2:-}" "\${3:-}" >> "$log_file"
    exit 0
    ;;
  push)
    printf '%s\\n' "$*" >> "$log_file"
    exit 0
    ;;
esac

exit 0
`;

const normalizePathFunction = `
normalize_path() {
  local input_path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$input_path"
  else
    printf '%s' "$input_path"
  fi
}
`;

const runGitAlias = (aliasCommand: string, refs: string[]): GitAliasRunResult => {
  const tempRoot = createTempRoot();
  const fakeGitRoot = path.join(tempRoot, "bin");
  const fakeGitPath = writeTextFile(fakeGitRoot, "git", fakeGitScript);
  const refsPath = writeTextFile(tempRoot, "refs.txt", refs.join("\n"));
  const logPath = writeTextFile(tempRoot, "git.log", "");

  fs.chmodSync(fakeGitPath, 0o755);

  const runnerScript = `
set -uo pipefail
shopt -s expand_aliases
${normalizePathFunction}

PROJECT_ROOT="$(normalize_path "$PROJECT_ROOT_PATH")"
FAKE_GIT_ROOT="$(normalize_path "$FAKE_GIT_ROOT_PATH")"
export FAKE_GIT_LOG="$(normalize_path "$FAKE_GIT_LOG_PATH")"
export FAKE_GIT_REFS_FILE="$(normalize_path "$FAKE_GIT_REFS_PATH")"
PATH="$FAKE_GIT_ROOT:$PATH"

source "$PROJECT_ROOT/aliases.sh"
${aliasCommand}
`;

  const result = spawnSync(bashExecutable, ["-lc", runnerScript], {
    encoding: "utf8",
    env: {
      ...process.env,
      FAKE_GIT_LOG_PATH: logPath,
      FAKE_GIT_REFS_PATH: refsPath,
      FAKE_GIT_ROOT_PATH: fakeGitRoot,
      PROJECT_ROOT_PATH: projectRoot,
    },
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  });

  if (result.error) {
    throw result.error;
  }

  const logLines = fs
    .readFileSync(logPath, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  return {
    logLines,
    status: result.status,
    stderr: result.stderr,
    stdout: result.stdout,
  };
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

describe("git branch aliases", () => {
  it.each([
    {
      aliasCommand: "gdev",
      expectedLogLines: ["checkout development", "pull origin development"],
      refs: ["refs/heads/development"],
    },
    {
      aliasCommand: "gdev",
      expectedLogLines: ["checkout dev", "pull origin dev"],
      refs: ["refs/remotes/origin/dev"],
    },
    {
      aliasCommand: "gmaster",
      expectedLogLines: ["checkout master", "pull origin master"],
      refs: ["refs/remotes/origin/master", "refs/remotes/origin/main"],
    },
    {
      aliasCommand: "gmaster",
      expectedLogLines: ["checkout main", "pull origin main"],
      refs: ["refs/heads/main"],
    },
    {
      aliasCommand: "gmain",
      expectedLogLines: ["checkout main", "pull origin main"],
      refs: ["refs/heads/main", "refs/heads/master"],
    },
    {
      aliasCommand: "gmain",
      expectedLogLines: ["checkout master", "pull origin master"],
      refs: ["refs/remotes/origin/master"],
    },
    {
      aliasCommand: "gplod",
      expectedLogLines: ["pull origin dev"],
      refs: ["refs/heads/dev"],
    },
    {
      aliasCommand: "gplom",
      expectedLogLines: ["pull origin main"],
      refs: ["refs/remotes/origin/main"],
    },
    {
      aliasCommand: "gpod",
      expectedLogLines: ["push origin dev"],
      refs: ["refs/remotes/origin/dev"],
    },
    {
      aliasCommand: "gpomain",
      expectedLogLines: ["push origin master"],
      refs: ["refs/heads/master"],
    },
  ])("routes $aliasCommand through the matching branch name", ({ aliasCommand, expectedLogLines, refs }) => {
    const result = runGitAlias(aliasCommand, refs);

    expect(result.status).toBe(0);
    expect(result.stdout).toBe("");
    expect(result.stderr).toBe("");
    expect(result.logLines).toEqual(expectedLogLines);
  });
});
