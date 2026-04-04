#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { createHash } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";

const projectRoot = process.cwd();
const concatOutputName = "temp.txt";
const fixtureScales = {
  tiny: {
    assetFiles: 4,
    distFiles: 8,
    docsFiles: 10,
    nestedFiles: 8,
    nodeModulesFiles: 12,
    srcFiles: 20,
  },
  small: {
    assetFiles: 12,
    distFiles: 20,
    docsFiles: 60,
    nestedFiles: 40,
    nodeModulesFiles: 80,
    srcFiles: 120,
  },
  medium: {
    assetFiles: 32,
    distFiles: 50,
    docsFiles: 250,
    nestedFiles: 150,
    nodeModulesFiles: 220,
    srcFiles: 600,
  },
  large: {
    assetFiles: 64,
    distFiles: 100,
    docsFiles: 600,
    nestedFiles: 400,
    nodeModulesFiles: 500,
    srcFiles: 1500,
  },
};

const usage = `Usage: node scripts/bench-concat.mjs [options]

Benchmarks the real concat function from aliases.sh.

Options:
  --target <path>      Benchmark an existing directory instead of a synthetic fixture.
  --scale <name>       Fixture scale: tiny, small, medium, large. Default: small.
  --iterations <n>     Measured iterations. Default: 3.
  --warmup <n>         Warmup iterations. Default: 1.
  --keep-fixture       Keep the generated synthetic fixture on disk.
  --keep-output        Keep the final temp.txt output when no original temp.txt existed.
  --help               Show this message.

Examples:
  pnpm bench:concat
  pnpm bench:concat -- --scale medium
  pnpm bench:concat -- --target .
`;

const parseArgs = (argv) => {
  const options = {
    iterations: 3,
    keepFixture: false,
    keepOutput: false,
    scale: "small",
    target: null,
    warmup: 1,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--help") {
      options.help = true;
      continue;
    }

    if (arg === "--keep-fixture") {
      options.keepFixture = true;
      continue;
    }

    if (arg === "--keep-output") {
      options.keepOutput = true;
      continue;
    }

    if (arg === "--target" || arg === "--scale" || arg === "--iterations" || arg === "--warmup") {
      const value = argv[index + 1];

      if (!value) {
        throw new Error(`Missing value for ${arg}.`);
      }

      index += 1;

      if (arg === "--target") {
        options.target = path.resolve(projectRoot, value);
      } else if (arg === "--scale") {
        options.scale = value;
      } else if (arg === "--iterations") {
        options.iterations = Number.parseInt(value, 10);
      } else if (arg === "--warmup") {
        options.warmup = Number.parseInt(value, 10);
      }

      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!Number.isInteger(options.iterations) || options.iterations <= 0) {
    throw new Error("--iterations must be a positive integer.");
  }

  if (!Number.isInteger(options.warmup) || options.warmup < 0) {
    throw new Error("--warmup must be a non-negative integer.");
  }

  if (!(options.scale in fixtureScales)) {
    throw new Error(
      `--scale must be one of: ${Object.keys(fixtureScales).join(", ")}.`
    );
  }

  return options;
};

const resolveBashExecutable = () => {
  if (process.platform !== "win32") {
    return "bash";
  }

  const candidates = [
    process.env.GIT_BASH_PATH,
    "C:\\Program Files\\Git\\bin\\bash.exe",
    "C:\\Program Files\\Git\\usr\\bin\\bash.exe",
    "C:\\Program Files (x86)\\Git\\bin\\bash.exe",
    "C:\\Program Files (x86)\\Git\\usr\\bin\\bash.exe",
  ].filter(Boolean);

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
    "Git Bash is required to run concat benchmarks on Windows. Set GIT_BASH_PATH if it is installed in a non-standard location."
  );
};

const bashExecutable = resolveBashExecutable();

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
concat "."
`;

const ensureParentDir = (filePath) => {
  fs.mkdirSync(path.dirname(filePath), {
    recursive: true,
  });
};

const writeTextFile = (rootDir, relativePath, contents) => {
  const absolutePath = path.join(rootDir, relativePath);
  ensureParentDir(absolutePath);
  fs.writeFileSync(absolutePath, contents, "utf8");
};

const writeBinaryFile = (rootDir, relativePath, buffer) => {
  const absolutePath = path.join(rootDir, relativePath);
  ensureParentDir(absolutePath);
  fs.writeFileSync(absolutePath, buffer);
};

const createSyntheticFixture = (scaleName) => {
  const scale = fixtureScales[scaleName];
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "concat-bench-"));

  writeTextFile(fixtureRoot, "README.md", "# concat benchmark fixture\n");
  writeTextFile(fixtureRoot, ".git/HEAD", "ref: refs/heads/main\n");
  writeTextFile(fixtureRoot, "config/.env", "SECRET=benchmark\n");
  writeTextFile(fixtureRoot, "pnpm-lock.yaml", "lockfileVersion: 9\n");
  writeTextFile(fixtureRoot, "src/empty.txt", "");
  writeTextFile(fixtureRoot, "src/with spaces.md", "spaced benchmark file\n");
  writeBinaryFile(
    fixtureRoot,
    "src/binary.txt",
    Buffer.from([0x00, 0x01, 0x02, 0x03, 0x00, 0xff])
  );
  writeBinaryFile(
    fixtureRoot,
    "big/huge.txt",
    Buffer.alloc(2 * 1024 * 1024 + 1, 0x41)
  );

  for (let index = 1; index <= scale.srcFiles; index += 1) {
    writeTextFile(
      fixtureRoot,
      `src/file${String(index).padStart(4, "0")}.ts`,
      `export const file${index} = ${index};\n`.repeat(4)
    );
  }

  for (let index = 1; index <= scale.docsFiles; index += 1) {
    writeTextFile(
      fixtureRoot,
      `docs/doc${String(index).padStart(4, "0")}.md`,
      `# Doc ${index}\ncontent line\n`.repeat(5)
    );
  }

  for (let index = 1; index <= scale.nestedFiles; index += 1) {
    writeTextFile(
      fixtureRoot,
      `nested/deep/item${String(index).padStart(4, "0")}.js`,
      `console.log(${index});\n`.repeat(4)
    );
  }

  for (let index = 1; index <= scale.nodeModulesFiles; index += 1) {
    writeTextFile(
      fixtureRoot,
      `node_modules/pkg${String(index).padStart(4, "0")}.js`,
      "module.exports = true;\n"
    );
    writeTextFile(
      fixtureRoot,
      `nested/node_modules/dep${String(index).padStart(4, "0")}.js`,
      "module.exports = true;\n"
    );
  }

  for (let index = 1; index <= scale.distFiles; index += 1) {
    writeTextFile(
      fixtureRoot,
      `dist/chunk${String(index).padStart(4, "0")}.js`,
      "compiled output\n".repeat(3)
    );
  }

  for (let index = 1; index <= scale.assetFiles; index += 1) {
    writeBinaryFile(
      fixtureRoot,
      `assets/image${String(index).padStart(4, "0")}.png`,
      Buffer.from([0x89, 0x50, 0x4e, 0x47, index % 255])
    );
  }

  return {
    fixtureRoot,
    metadata: {
      excludedCandidates:
        scale.assetFiles + scale.nodeModulesFiles * 2 + scale.distFiles + 4,
      includedCandidates: scale.srcFiles + scale.docsFiles + scale.nestedFiles + 3,
      scale: scaleName,
    },
  };
};

const readSummaryCount = (output, label) => {
  const escapedLabel = label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = output.match(new RegExp(`^// ${escapedLabel}:\\s+(\\d+)$`, "m"));

  if (!match) {
    throw new Error(`Missing summary line for "${label}".`);
  }

  return Number(match[1]);
};

const countLines = (text) => {
  if (text.length === 0) {
    return 0;
  }

  const newlineCount = text.match(/\n/g)?.length ?? 0;
  return text.endsWith("\n") ? newlineCount : newlineCount + 1;
};

const hashText = (text) => {
  return createHash("sha256").update(text).digest("hex").slice(0, 16);
};

const formatBytes = (bytes) => {
  const units = ["B", "KB", "MB", "GB"];
  let value = bytes;
  let unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }

  return `${value.toFixed(unitIndex === 0 ? 0 : 2)} ${units[unitIndex]}`;
};

const formatDuration = (durationMs) => {
  if (durationMs >= 1000) {
    return `${(durationMs / 1000).toFixed(2)} s`;
  }

  return `${durationMs.toFixed(0)} ms`;
};

const summarizeDurations = (durationsMs) => {
  const sorted = [...durationsMs].sort((left, right) => left - right);
  const sum = durationsMs.reduce((total, value) => total + value, 0);
  const midpoint = Math.floor(sorted.length / 2);
  const median =
    sorted.length % 2 === 0
      ? (sorted[midpoint - 1] + sorted[midpoint]) / 2
      : sorted[midpoint];

  return {
    average: sum / durationsMs.length,
    max: sorted[sorted.length - 1],
    median,
    min: sorted[0],
  };
};

const runConcatOnce = (targetRoot) => {
  const startedAt = process.hrtime.bigint();
  const result = spawnSync(bashExecutable, ["-lc", concatRunnerScript], {
    encoding: "utf8",
    env: {
      ...process.env,
      PROJECT_ROOT_PATH: projectRoot,
      TARGET_ROOT_PATH: targetRoot,
    },
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  });
  const endedAt = process.hrtime.bigint();

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    const details = [
      `concat benchmark run failed with exit code ${result.status}.`,
      result.stderr.trim() ? `stderr:\n${result.stderr.trim()}` : "",
      result.stdout.trim() ? `stdout:\n${result.stdout.trim()}` : "",
    ]
      .filter(Boolean)
      .join("\n\n");

    throw new Error(details);
  }

  const outputPath = path.join(targetRoot, concatOutputName);

  if (!fs.existsSync(outputPath)) {
    throw new Error(`concat did not create ${outputPath}.`);
  }

  const output = fs.readFileSync(outputPath, "utf8");

  return {
    durationMs: Number(endedAt - startedAt) / 1_000_000,
    output,
    outputPath,
    stderr: result.stderr.trim(),
    stdout: result.stdout.trim(),
    summary: {
      excludedDirectories: readSummaryCount(output, "Excluded directories (pruned)"),
      excludedFiles: readSummaryCount(output, "Excluded files (names only)"),
      includedFiles: readSummaryCount(output, "Included files (contents copied)"),
    },
  };
};

const main = () => {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    console.log(usage);
    return;
  }

  let targetRoot = options.target;
  let fixtureMetadata = null;

  if (targetRoot) {
    if (!fs.existsSync(targetRoot) || !fs.statSync(targetRoot).isDirectory()) {
      throw new Error(`Target directory not found: ${targetRoot}`);
    }
  } else {
    const fixture = createSyntheticFixture(options.scale);
    targetRoot = fixture.fixtureRoot;
    fixtureMetadata = fixture.metadata;
  }

  const outputPath = path.join(targetRoot, concatOutputName);
  const hadOriginalOutput = fs.existsSync(outputPath);
  const originalOutput = hadOriginalOutput ? fs.readFileSync(outputPath) : null;
  const measuredRuns = [];

  console.log("concat benchmark");
  console.log(`Bash: ${bashExecutable}`);
  console.log(`Mode: ${options.target ? "existing directory" : `synthetic fixture (${options.scale})`}`);
  console.log(`Target: ${targetRoot}`);
  console.log(`Warmup iterations: ${options.warmup}`);
  console.log(`Measured iterations: ${options.iterations}`);

  if (fixtureMetadata) {
    console.log(
      `Fixture shape: ~${fixtureMetadata.includedCandidates} included candidates, ~${fixtureMetadata.excludedCandidates} excluded/pruned candidates`
    );
  }

  if (hadOriginalOutput) {
    console.log(`Note: existing ${concatOutputName} will be restored after the benchmark.`);
  }

  console.log("");

  for (let index = 0; index < options.warmup; index += 1) {
    const run = runConcatOnce(targetRoot);
    console.log(
      `warmup ${index + 1}/${options.warmup}: ${formatDuration(run.durationMs)}`
    );
  }

  if (options.warmup > 0) {
    console.log("");
  }

  for (let index = 0; index < options.iterations; index += 1) {
    const run = runConcatOnce(targetRoot);
    const outputBytes = Buffer.byteLength(run.output);
    const outputLines = countLines(run.output);
    const outputHash = hashText(run.output);

    measuredRuns.push({
      durationMs: run.durationMs,
      outputBytes,
      outputHash,
      outputLines,
      summary: run.summary,
    });

    console.log(
      [
        `run ${index + 1}/${options.iterations}: ${formatDuration(run.durationMs)}`,
        `${formatBytes(outputBytes)}`,
        `${outputLines} lines`,
        `included ${run.summary.includedFiles}`,
        `excluded ${run.summary.excludedFiles}`,
        `pruned ${run.summary.excludedDirectories}`,
        `sha ${outputHash}`,
      ].join(" | ")
    );
  }

  console.log("");

  const durationSummary = summarizeDurations(
    measuredRuns.map((run) => run.durationMs)
  );
  const outputHashes = new Set(measuredRuns.map((run) => run.outputHash));
  const lastRun = measuredRuns[measuredRuns.length - 1];

  console.log("summary");
  console.log(`min: ${formatDuration(durationSummary.min)}`);
  console.log(`median: ${formatDuration(durationSummary.median)}`);
  console.log(`avg: ${formatDuration(durationSummary.average)}`);
  console.log(`max: ${formatDuration(durationSummary.max)}`);
  console.log(
    `output: ${formatBytes(lastRun.outputBytes)}, ${lastRun.outputLines} lines, sha ${lastRun.outputHash}`
  );

  if (outputHashes.size !== 1) {
    console.log(`warning: output hash varied across runs (${[...outputHashes].join(", ")})`);
  }

  if (hadOriginalOutput && originalOutput) {
    fs.writeFileSync(outputPath, originalOutput);
  } else if (!options.keepOutput && fs.existsSync(outputPath)) {
    fs.rmSync(outputPath, {
      force: true,
    });
  }

  if (!options.target && !options.keepFixture) {
    fs.rmSync(targetRoot, {
      force: true,
      recursive: true,
    });
  } else if (!options.target && options.keepFixture) {
    console.log(`fixture kept at: ${targetRoot}`);
  }

  if (!hadOriginalOutput && options.keepOutput && fs.existsSync(outputPath)) {
    console.log(`output kept at: ${outputPath}`);
  }
};

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
