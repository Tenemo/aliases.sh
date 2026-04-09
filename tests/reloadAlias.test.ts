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
    "Git Bash is required to run reload alias tests on Windows. Set GIT_BASH_PATH if it is installed in a non-standard location."
  );
};

const bashExecutable = resolveBashExecutable();

const createTempRoot = (): string => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "reload-alias-test-"));
  tempRoots.push(tempRoot);
  return tempRoot;
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

type ReloadRunResult = {
  status: number | null;
  stderr: string;
  stdout: string;
};

const reloadRunnerScript = `
set -uo pipefail
shopt -s expand_aliases

normalize_path() {
  local input_path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$input_path"
  else
    printf '%s' "$input_path"
  fi
}

ALIASES_FILE="$(normalize_path "$ALIASES_FILE_PATH")"
WORK_ROOT="$(normalize_path "$WORK_ROOT_PATH")"

source "$ALIASES_FILE"
if ! alias reload >/dev/null; then
  echo "reload alias is not defined" >&2
  exit 1
fi
alias __reload_probe='printf before'
mkdir -p "$WORK_ROOT/nested"
cd "$WORK_ROOT/nested"
printf "\\nalias __reload_probe='printf after'\\n" >> "$ALIASES_FILE"
reload
RELOAD_STATUS=$?
if [ "$RELOAD_STATUS" -ne 0 ]; then
  exit "$RELOAD_STATUS"
fi
__reload_probe
`;

const runReloadProbe = (aliasesFile: string, workRoot: string): ReloadRunResult => {
  const result = spawnSync(bashExecutable, ["-lc", reloadRunnerScript], {
    encoding: "utf8",
    env: {
      ...process.env,
      ALIASES_FILE_PATH: aliasesFile,
      WORK_ROOT_PATH: workRoot,
    },
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  });

  if (result.error) {
    throw result.error;
  }

  return {
    status: result.status,
    stderr: result.stderr,
    stdout: result.stdout,
  };
};

describe("reload alias", () => {
  it("reloads aliases from the same sourced file after the working directory changes", () => {
    const tempRoot = createTempRoot();
    const aliasesFile = path.join(tempRoot, "aliases.sh");

    fs.copyFileSync(path.join(projectRoot, "aliases.sh"), aliasesFile);

    const result = runReloadProbe(aliasesFile, tempRoot);

    expect(result.status).toBe(0);
    expect(result.stderr).toBe("");
    expect(result.stdout).toBe("after");
  });
});
