## aliases.sh

[![Netlify Status](https://api.netlify.com/api/v1/badges/93940616-2c34-494c-815b-4fa1b98d6be3/deploy-status)](https://app.netlify.com/sites/aliases-sh/deploys)

[aliases.sh](https://aliases.sh)

A tiny static site that publishes my curated bash aliases and renders the real [aliases.sh](./aliases.sh) file with build-time syntax highlighting.

### How it works

- `index.html` contains the site metadata directly and uses an explicit placeholder for the aliases code block.
- `src/injectAliases.ts` inlines the Highlight.js theme and renders the real `aliases.sh` content at build/dev time.
- The built site is static and does not include runtime browser JavaScript.
- `concat` is a Bash wrapper over an inline Node engine at the end of `aliases.sh`.
- `concat` supports `--exclude` with quoted `.gitignore`-like patterns, and one `--exclude` can take multiple patterns.

### Concat examples

Quote glob patterns so your shell does not expand them before `concat` sees them.

```bash
# Snapshot the current directory into temp.txt
concat .

# Snapshot a specific subdirectory
concat ./src

# Exclude a generated directory anywhere in the tree
concat --exclude 'generated/'

# Exclude all snapshot files
concat --exclude '**/*.snap'

# Exclude only the root README.md
concat --exclude '/README.md'

# Pass multiple patterns after a single --exclude
concat --exclude 'generated/' '**/*.md'

# Use a bash array as the pattern list
exclude_patterns=('generated/' '**/*.md')
concat --exclude "${exclude_patterns[@]}"

# Exclude test files and coverage output together
concat . --exclude '**/*.test.ts' 'coverage/'

# Combine root-anchored, file, and directory exclusions
concat ./src --exclude 'generated/' '**/*.snap' '/README.md'
```

### Local development

```bash
pnpm install
pnpm dev
pnpm test
pnpm bench:concat
pnpm build
```

Optional benchmark examples:

```bash
pnpm bench:concat
pnpm bench:concat -- --scale medium
pnpm bench:concat -- --target .
```

### Concat benchmark

`pnpm bench:concat` runs the real `concat` function from [aliases.sh](./aliases.sh). The harness launches Git Bash, sources the aliases file, runs `concat "."`, and measures wall-clock time around the full invocation, including snapshot generation and writing `temp.txt`.

By default it benchmarks against a synthetic fixture that mixes:

- Included source and docs files
- Pruned directories like `.git`, `dist`, and `node_modules`
- Excluded files such as `.env`, lockfiles, large files, and binary assets

If you pass `--target <path>`, it benchmarks an existing directory instead. The benchmark restores an existing `temp.txt` after each run, removes generated fixtures unless told not to, and reports per-run output size, line count, included/excluded counts, output hash, plus min/median/avg/max timings.

Arguments:

- `--target <path>`: benchmark an existing directory instead of generating a fixture
- `--scale <tiny|small|medium|large>`: choose the synthetic fixture size, default `small`
- `--iterations <n>`: number of measured runs, default `3`
- `--warmup <n>`: number of warmup runs before measuring, default `1`
- `--keep-fixture`: keep the generated synthetic fixture on disk
- `--keep-output`: keep the benchmark-generated `temp.txt` when there was no original one
- `--help`: print the built-in usage text

On Windows, the harness needs Git Bash. Set `GIT_BASH_PATH` if it is installed outside the usual locations.

### Notes

- `aliases.sh` itself is currently Bash-oriented. This repo does not guarantee zsh compatibility.
- `concat` now requires Node, but the full implementation is inlined inside `aliases.sh`.
