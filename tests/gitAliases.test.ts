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

type CommandResult = {
  status: number | null;
  stderr: string;
  stdout: string;
};

type GitAliasRunResult = CommandResult & {
  logLines: string[];
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

const appendTextFile = (rootDir: string, relativePath: string, contents: string): string => {
  const absolutePath = path.join(rootDir, relativePath);
  fs.mkdirSync(path.dirname(absolutePath), {
    recursive: true,
  });
  fs.appendFileSync(absolutePath, contents, "utf8");
  return absolutePath;
};

const runCommand = (
  command: string,
  args: string[],
  options: {
    cwd?: string;
    env?: NodeJS.ProcessEnv;
  } = {}
): CommandResult => {
  const result = spawnSync(command, args, {
    cwd: options.cwd,
    encoding: "utf8",
    env: options.env,
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

const runGitOrThrow = (cwd: string, args: string[]): string => {
  const result = runCommand("git", args, {
    cwd,
  });

  if (result.status !== 0) {
    throw new Error(
      [
        `git ${args.join(" ")} failed in ${cwd}`,
        `stdout:\n${result.stdout}`,
        `stderr:\n${result.stderr}`,
      ].join("\n\n")
    );
  }

  return result.stdout;
};

const runAliasInDirectory = (workingDirectory: string, aliasCommand: string): CommandResult => {
  const runnerScript = `
set -uo pipefail
shopt -s expand_aliases
${normalizePathFunction}

PROJECT_ROOT="$(normalize_path "$PROJECT_ROOT_PATH")"
WORKING_DIRECTORY="$(normalize_path "$WORKING_DIRECTORY_PATH")"
cd "$WORKING_DIRECTORY"

source "$PROJECT_ROOT/aliases.sh"
${aliasCommand}
`;

  return runCommand(bashExecutable, ["-lc", runnerScript], {
    env: {
      ...process.env,
      PROJECT_ROOT_PATH: projectRoot,
      WORKING_DIRECTORY_PATH: workingDirectory,
    },
  });
};

const commitFile = (
  repoDir: string,
  relativePath: string,
  contents: string,
  message: string
): void => {
  writeTextFile(repoDir, relativePath, contents);
  runGitOrThrow(repoDir, ["add", relativePath]);
  runGitOrThrow(repoDir, ["commit", "-m", message]);
};

const appendAndCommitFile = (
  repoDir: string,
  relativePath: string,
  contents: string,
  message: string
): void => {
  appendTextFile(repoDir, relativePath, contents);
  runGitOrThrow(repoDir, ["add", relativePath]);
  runGitOrThrow(repoDir, ["commit", "-m", message]);
};

const initializeGitPruneFixture = (): string => {
  const tempRoot = createTempRoot();
  const originDir = path.join(tempRoot, "origin.git");
  const repoDir = path.join(tempRoot, "repo");

  runGitOrThrow(tempRoot, ["init", "--bare", "--initial-branch=main", originDir]);
  runGitOrThrow(tempRoot, ["clone", originDir, repoDir]);
  runGitOrThrow(repoDir, ["config", "user.name", "test user"]);
  runGitOrThrow(repoDir, ["config", "user.email", "test@example.com"]);
  runGitOrThrow(repoDir, ["checkout", "-b", "main"]);
  commitFile(repoDir, "README.md", "initial\n", "initial commit");
  runGitOrThrow(repoDir, ["push", "-u", "origin", "main"]);
  runGitOrThrow(repoDir, ["remote", "set-head", "origin", "main"]);

  return repoDir;
};

const listLocalBranches = (repoDir: string): string[] => {
  return runGitOrThrow(repoDir, ["for-each-ref", "--format=%(refname:short)", "refs/heads"])
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .sort();
};

const currentBranchName = (repoDir: string): string => {
  return runGitOrThrow(repoDir, ["branch", "--show-current"]).trim();
};

const createBranchWithCommits = (
  repoDir: string,
  branchName: string,
  commits: Array<{
    append?: boolean;
    message: string;
    path: string;
    contents: string;
  }>
): void => {
  runGitOrThrow(repoDir, ["checkout", "-b", branchName, "main"]);

  for (const commit of commits) {
    if (commit.append) {
      appendAndCommitFile(repoDir, commit.path, commit.contents, commit.message);
    } else {
      commitFile(repoDir, commit.path, commit.contents, commit.message);
    }
  }
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

describe("gprune", () => {
  it("deletes only branches whose gone upstream work already landed on origin/main", () => {
    const repoDir = initializeGitPruneFixture();

    createBranchWithCommits(repoDir, "feature-merged", [
      {
        contents: "merged branch\n",
        message: "add merged branch",
        path: "feature-merged.txt",
      },
    ]);
    runGitOrThrow(repoDir, ["push", "-u", "origin", "feature-merged"]);
    runGitOrThrow(repoDir, ["checkout", "main"]);
    runGitOrThrow(repoDir, ["merge", "--no-ff", "feature-merged", "-m", "merge feature-merged"]);
    runGitOrThrow(repoDir, ["push", "origin", "main"]);
    runGitOrThrow(repoDir, ["push", "origin", "--delete", "feature-merged"]);

    createBranchWithCommits(repoDir, "feature-squashed", [
      {
        contents: "squashed line one\n",
        message: "add first squash commit",
        path: "feature-squashed.txt",
      },
      {
        append: true,
        contents: "squashed line two\n",
        message: "add second squash commit",
        path: "feature-squashed.txt",
      },
    ]);
    runGitOrThrow(repoDir, ["push", "-u", "origin", "feature-squashed"]);
    runGitOrThrow(repoDir, ["checkout", "main"]);
    runGitOrThrow(repoDir, ["merge", "--squash", "feature-squashed"]);
    runGitOrThrow(repoDir, ["commit", "-m", "squash feature-squashed"]);
    runGitOrThrow(repoDir, ["push", "origin", "main"]);
    runGitOrThrow(repoDir, ["push", "origin", "--delete", "feature-squashed"]);

    createBranchWithCommits(repoDir, "feature-unmerged", [
      {
        contents: "unmerged branch\n",
        message: "add unmerged branch",
        path: "feature-unmerged.txt",
      },
    ]);
    runGitOrThrow(repoDir, ["push", "-u", "origin", "feature-unmerged"]);
    runGitOrThrow(repoDir, ["push", "origin", "--delete", "feature-unmerged"]);

    createBranchWithCommits(repoDir, "feature-live", [
      {
        contents: "live branch\n",
        message: "add live branch",
        path: "feature-live.txt",
      },
    ]);
    runGitOrThrow(repoDir, ["push", "-u", "origin", "feature-live"]);
    runGitOrThrow(repoDir, ["checkout", "main"]);

    createBranchWithCommits(repoDir, "feature-local-only", [
      {
        contents: "local only branch\n",
        message: "add local only branch",
        path: "feature-local-only.txt",
      },
    ]);
    runGitOrThrow(repoDir, ["checkout", "main"]);

    createBranchWithCommits(repoDir, "feature-current", [
      {
        contents: "current branch\n",
        message: "add current branch",
        path: "feature-current.txt",
      },
    ]);
    runGitOrThrow(repoDir, ["push", "-u", "origin", "feature-current"]);
    runGitOrThrow(repoDir, ["checkout", "main"]);
    runGitOrThrow(repoDir, ["push", "origin", "--delete", "feature-current"]);
    runGitOrThrow(repoDir, ["checkout", "feature-current"]);

    expect(listLocalBranches(repoDir)).toEqual([
      "feature-current",
      "feature-live",
      "feature-local-only",
      "feature-merged",
      "feature-squashed",
      "feature-unmerged",
      "main",
    ]);

    const result = runAliasInDirectory(repoDir, "gprune");

    expect(result.status).toBe(0);
    expect(result.stdout).toContain(
      "gprune: deleted feature-merged (merged into origin/main)"
    );
    expect(result.stdout).toContain(
      "gprune: deleted feature-squashed (squash-merged into origin/main)"
    );
    expect(result.stdout).toContain(
      "gprune: keeping feature-unmerged (upstream gone, but not found on origin/main)"
    );
    expect(result.stdout).toContain(
      "gprune: keeping feature-current (currently checked out)"
    );
    expect(result.stdout).toContain("gprune: deleted 2 branch(es).");
    expect(result.stdout).toContain("gprune: kept 2 branch(es).");
    expect(listLocalBranches(repoDir)).toEqual([
      "feature-current",
      "feature-live",
      "feature-local-only",
      "feature-unmerged",
      "main",
    ]);
    expect(currentBranchName(repoDir)).toBe("feature-current");
  }, 30000);

  it("supports dry-run mode without removing any local branches", () => {
    const repoDir = initializeGitPruneFixture();

    createBranchWithCommits(repoDir, "feature-merged", [
      {
        contents: "merged branch\n",
        message: "add merged branch",
        path: "feature-merged.txt",
      },
    ]);
    runGitOrThrow(repoDir, ["push", "-u", "origin", "feature-merged"]);
    runGitOrThrow(repoDir, ["checkout", "main"]);
    runGitOrThrow(repoDir, ["merge", "--no-ff", "feature-merged", "-m", "merge feature-merged"]);
    runGitOrThrow(repoDir, ["push", "origin", "main"]);
    runGitOrThrow(repoDir, ["push", "origin", "--delete", "feature-merged"]);

    createBranchWithCommits(repoDir, "feature-squashed", [
      {
        contents: "squashed line one\n",
        message: "add first squash commit",
        path: "feature-squashed.txt",
      },
      {
        append: true,
        contents: "squashed line two\n",
        message: "add second squash commit",
        path: "feature-squashed.txt",
      },
    ]);
    runGitOrThrow(repoDir, ["push", "-u", "origin", "feature-squashed"]);
    runGitOrThrow(repoDir, ["checkout", "main"]);
    runGitOrThrow(repoDir, ["merge", "--squash", "feature-squashed"]);
    runGitOrThrow(repoDir, ["commit", "-m", "squash feature-squashed"]);
    runGitOrThrow(repoDir, ["push", "origin", "main"]);
    runGitOrThrow(repoDir, ["push", "origin", "--delete", "feature-squashed"]);

    const branchesBefore = listLocalBranches(repoDir);
    const result = runAliasInDirectory(repoDir, "gprune --dry-run");

    expect(result.status).toBe(0);
    expect(result.stdout).toContain(
      "gprune: would delete feature-merged (merged into origin/main)"
    );
    expect(result.stdout).toContain(
      "gprune: would delete feature-squashed (squash-merged into origin/main)"
    );
    expect(result.stdout).toContain("gprune: 2 branch(es) would be deleted.");
    expect(listLocalBranches(repoDir)).toEqual(branchesBefore);
  }, 30000);

  it("rejects unexpected arguments", () => {
    const repoDir = initializeGitPruneFixture();
    const result = runAliasInDirectory(repoDir, "gprune --unexpected");

    expect(result.status).toBe(2);
    expect(result.stdout).toBe("");
    expect(result.stderr).toContain("Usage: gprune [--dry-run]");
    expect(listLocalBranches(repoDir)).toEqual(["main"]);
  }, 30000);
});
