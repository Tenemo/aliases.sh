# https://github.com/Tenemo/aliases.sh
#
# Default location on Windows: C:\Program Files\Git\etc\profile.d\aliases.sh
# Default location on MacOS: ~/.zshrc
# After updating a loaded file, run `reload` to apply changes without restarting.

__aliases_default_source_file() {
    if [ "$(uname)" = "Darwin" ]; then
        printf '%s\n' "$HOME/.zshrc"
    else
        printf '%s\n' "/c/Program Files/Git/etc/profile.d/aliases.sh"
    fi
}

__aliases_current_source_file() {
    if [ -n "${BASH_VERSION:-}" ] && [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        local SOURCE_DIR
        SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
        if [ -n "$SOURCE_DIR" ]; then
            printf '%s/%s\n' "$SOURCE_DIR" "$(basename "${BASH_SOURCE[0]}")"
            return 0
        fi
    fi

    __aliases_default_source_file
}

__ALIASES_SOURCE_FILE="$(__aliases_current_source_file)"

__aliases_source_file() {
    if [ -n "${__ALIASES_SOURCE_FILE:-}" ] && [ -f "$__ALIASES_SOURCE_FILE" ]; then
        printf '%s\n' "$__ALIASES_SOURCE_FILE"
    else
        __aliases_default_source_file
    fi
}

__reload_aliases() {
    local SRC
    SRC="$(__aliases_source_file)"
    if [ ! -f "$SRC" ]; then
        echo "reload: aliases file not found: $SRC" >&2
        return 1
    fi

    source "$SRC"
}

unalias reload 2>/dev/null
alias reload='__reload_aliases'

# It's aliases all the way down.
unalias aliases 2>/dev/null
aliases() {
    local SRC
    SRC="$(__aliases_source_file)"
    if [ -f "$SRC" ]; then
        grep '^[[:space:]]*alias ' "$SRC" | sed 's/^[[:space:]]*alias[[:space:]]*//'
    else
        alias | sed 's/^alias //' | sort
    fi
}

if [ "$(uname)" = "Darwin" ]; then
    alias ls='ls -F -G'
else
    alias ls='ls -F --color=auto --show-control-chars'
fi
alias ll='ls -l'

# For working with LLMs
concat() {
    local DIRECTORY_TO_SEARCH="./"
    local OUTPUT_FILE="temp.txt"
    local DIRECTORY_SET=0
    local EXPECTING_EXCLUDE_PATTERN=0
    local EXCLUDE_PATTERN_COUNT=0
    local ARG
    local -a EXCLUDE_PATTERNS=()

    while [ "$#" -gt 0 ]; do
        ARG="$1"
        shift

        if [ "$EXPECTING_EXCLUDE_PATTERN" -eq 1 ]; then
            case "$ARG" in
                --exclude)
                    if [ "$EXCLUDE_PATTERN_COUNT" -eq 0 ]; then
                        echo "concat: --exclude requires at least one pattern" >&2
                        return 2
                    fi
                    EXCLUDE_PATTERN_COUNT=0
                    continue
                    ;;
                --)
                    if [ "$EXCLUDE_PATTERN_COUNT" -eq 0 ]; then
                        echo "concat: --exclude requires at least one pattern" >&2
                        return 2
                    fi
                    EXPECTING_EXCLUDE_PATTERN=0
                    EXCLUDE_PATTERN_COUNT=0
                    continue
                    ;;
            esac

            EXCLUDE_PATTERNS+=("$ARG")
            EXCLUDE_PATTERN_COUNT=$((EXCLUDE_PATTERN_COUNT + 1))
            continue
        fi

        case "$ARG" in
            --exclude)
                EXPECTING_EXCLUDE_PATTERN=1
                EXCLUDE_PATTERN_COUNT=0
                ;;
            --)
                ;;
            -*)
                echo "concat: unknown option: $ARG" >&2
                return 2
                ;;
            *)
                if [ "$DIRECTORY_SET" -eq 0 ]; then
                    DIRECTORY_TO_SEARCH="$ARG"
                    DIRECTORY_SET=1
                else
                    EXCLUDE_PATTERNS+=("$ARG")
                fi
                ;;
        esac
    done

    if [ "$EXPECTING_EXCLUDE_PATTERN" -eq 1 ] && [ "$EXCLUDE_PATTERN_COUNT" -eq 0 ]; then
        echo "concat: --exclude requires at least one pattern" >&2
        return 2
    fi

    if [ ! -d "$DIRECTORY_TO_SEARCH" ]; then
        echo "concat: directory not found: $DIRECTORY_TO_SEARCH" >&2
        return 2
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo "concat: node is required" >&2
        return 1
    fi

    __concat_node "$DIRECTORY_TO_SEARCH" "$OUTPUT_FILE" "${EXCLUDE_PATTERNS[@]}"
}

alias i='npm install'

unalias s 2>/dev/null
s() {
    npm start
    local STATUS=$?
    if [ "$STATUS" -eq 130 ]; then
        return 130
    fi
    if [ "$STATUS" -ne 0 ]; then
        npm run dev
        return $?
    fi
    return 0
}

alias r='npm run'
alias b='npm run build'
alias d='npm run deploy'
alias bs='npm run build:skip'
alias t='npm test'
alias u='npm test -- -u'
alias od='npm outdated'
alias up='npm update'
alias un='npm uninstall'

alias cu='ncu --packageFile package.json'
alias cuu='ncu --packageFile package.json -u && rm -rf package-lock.json node_modules && npm install'
alias cxuu='ncu --packageFile package.json -u -x "history" && rm -rf package-lock.json node_modules && npm install'
alias cruu='ncu --packageFile package.json -u -x react,react-dom  && rm -rf package-lock.json node_modules && npm install'

alias pnpmup='pnpm -r up --latest && pnpm install --force'

alias global='npm list -g --depth 0'
alias globaloutdated='npm outdated -g --depth=0'
alias nuke_modules='rm -rf node_modules package-lock.json && npm install'
alias nuke_modules_nolock='rm -rf node_modules && npm install'
alias nuke_clean='rm -rf node_modules && npm ci' # Safer, uses lockfile exactly

alias gla='git config -l | grep alias | cut -c 7-'

alias gcl='git clone'
alias ga='git add'
alias gaa='git add .'
alias gs='git status'
alias gcp='git cherry-pick'

alias gco='git checkout'
alias gcob='git checkout -b'
alias gcoo='git fetch && git checkout'

# Resolve shared branch-name conventions without forcing a single default.
_git_branch_exists() {
    local BRANCH="$1"
    git show-ref --verify --quiet "refs/heads/$BRANCH" >/dev/null 2>&1 || \
        git show-ref --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null 2>&1
}
_git_resolve_named_branch() {
    local BRANCH
    for BRANCH in "$@"; do
        if _git_branch_exists "$BRANCH"; then
            printf '%s\n' "$BRANCH"
            return 0
        fi
    done
    printf '%s\n' "$1"
}
_git_checkout_pull_named_branch() {
    local BRANCH
    BRANCH="$(_git_resolve_named_branch "$@")"
    git checkout "$BRANCH" && git pull origin "$BRANCH"
}
_git_pull_named_branch() {
    local BRANCH
    BRANCH="$(_git_resolve_named_branch "$@")"
    git pull origin "$BRANCH"
}
_git_push_named_branch() {
    local BRANCH
    BRANCH="$(_git_resolve_named_branch "$@")"
    git push origin "$BRANCH"
}

alias gdev='_git_checkout_pull_named_branch development dev'
alias gstaging='git checkout staging && git pull origin staging'

alias gmaster='_git_checkout_pull_named_branch master main'
alias gmain='_git_checkout_pull_named_branch main master'

alias gc='git commit'
alias gamend='git commit --amend --no-edit'
alias gaamend='git add . && git commit --amend --no-edit'

gcm() {
    [ $# -gt 0 ] || { echo "Usage: gcm <commit message>" >&2; return 2; }
    git commit -m "$*"
}
gac() {
    [ $# -gt 0 ] || { echo "Usage: gac <commit message>" >&2; return 2; }
    git add . && git commit -m "$*"
}
gacgo() {
    [ $# -gt 0 ] || { echo "Usage: gacgo <commit message>" >&2; return 2; }
    git add . && git commit -m "$*" --no-verify
}
_git_push_origin_current() {
    local BRANCH
    BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    if [ -z "$BRANCH" ] || [ "$BRANCH" = "HEAD" ]; then
        echo "_git_push_origin_current: not on a branch (detached HEAD)." >&2
        echo "Use: git push <remote> HEAD:<branch>" >&2
        return 2
    fi
    if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        git push "$@" origin "$BRANCH"
    else
        git push "$@" --set-upstream origin "$BRANCH"
    fi
}
gogo() {
    [ $# -gt 0 ] || { echo "Usage: gogo <commit message>" >&2; return 2; }
    git add . && git commit -m "$*" && _git_push_origin_current
}
gogogo() {
    # WARNING: This skips pre-commit hooks. Use with caution.
    [ $# -gt 0 ] || { echo "Usage: gogogo <commit message>" >&2; return 2; }
    git add . && git commit -m "$*" --no-verify && _git_push_origin_current --no-verify
}

listall() {
    find . \
        -not -path "./node_modules/*" \
        -not -path "./.git/*" \
        -not -path "./.husky/*" \
        -type f -print | sed 's|^\./||'
}

alias gbr='git branch'
alias gbrd='git branch -d'

alias gdlc='git diff --cached HEAD^ -- ":(exclude)package-lock.json"'
gdc() {
    if [ -n "$1" ]; then
        git diff "$1" --cached -- ":(exclude)package-lock.json"
    else
        git diff --cached -- ":(exclude)package-lock.json"
    fi
}
gdiff() {
    if [ -n "$1" ]; then
        git diff "$1" --word-diff -- ":(exclude)package-lock.json" ":(exclude)pnpm-lock.yaml"
    else
        git diff --word-diff -- ":(exclude)package-lock.json" ":(exclude)pnpm-lock.yaml"
    fi
}
gdiffloc() {
    if [ -n "$1" ]; then
        git diff --shortstat "$1" -- ":(exclude)package-lock.json" ":(exclude)pnpm-lock.yaml"
    else
        git diff --shortstat -- ":(exclude)package-lock.json" ":(exclude)pnpm-lock.yaml"
    fi
}

alias gplo='git pull origin'
alias gplod='_git_pull_named_branch development dev'
alias gplos='git pull origin staging'
alias gplom='_git_pull_named_branch master main'
alias gplomain='_git_pull_named_branch main master'

unalias gploh 2>/dev/null
gploh() {
    local BRANCH
    BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    if [ -z "$BRANCH" ] || [ "$BRANCH" = "HEAD" ]; then
        echo "gploh: not on a branch (detached HEAD). Use: git pull <remote> <branch>" >&2
        return 2
    fi
    git pull origin "$BRANCH"
}

unalias gpo 2>/dev/null
gpo() {
    _git_push_origin_current
}
unalias gforce 2>/dev/null
gforce() {
    _git_push_origin_current --force-with-lease
}
alias gpod='_git_push_named_branch development dev'
alias gpos='git push origin staging'
alias gpom='_git_push_named_branch master main'
alias gpomain='_git_push_named_branch main master'
unalias gpoh 2>/dev/null
gpoh() {
    _git_push_origin_current
}

alias gr='git reset'
alias gr1='git reset HEAD^'
alias gr2='git reset HEAD^^'
alias grh='git reset --hard'
alias grh1='git reset HEAD^ --hard'
alias grh2='git reset HEAD^^ --hard'
alias gunstage='git reset --soft HEAD^'

alias gst='git stash'
alias gsl='git stash list'
alias gsa='git stash apply'
alias gss='git stash push'

alias ggr='git log --graph --full-history --all --color --pretty=tformat:"%x1b[31m%h%x09%x1b[32m%d%x1b[0m%x20%s%x20%x1b[33m(%an)%x1b[0m"'
alias gls='git log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate'
alias gll='git log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate --numstat'
alias gld='git log --pretty=format:"%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate --date=relative'
alias glds='git log --pretty=format:"%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate --date=short'

unalias gdl 2>/dev/null
gdl() {
    if git config --get alias.ll >/dev/null 2>&1; then
        git ll -1
    else
        git log -1
    fi
}

_git_default_origin_branch() {
    local REF
    local BRANCH

    REF="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" || REF=""
    BRANCH="${REF#origin/}"
    if [ -n "$BRANCH" ] && [ "$BRANCH" != "$REF" ]; then
        printf '%s\n' "$BRANCH"
        return 0
    fi

    for BRANCH in main master development dev staging
    do
        if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
            printf '%s\n' "$BRANCH"
            return 0
        fi
    done

    return 1
}

_git_patch_id_for_range() {
    git diff "$1" "$2" | git patch-id --stable | awk 'NR == 1 { print $1 }'
}

_git_patch_id_for_commit() {
    git show --format= --patch "$1" | git patch-id --stable | awk 'NR == 1 { print $1 }'
}

_git_branch_matches_squash_merge() {
    local BRANCH="$1"
    local BASE_REF="$2"
    local MERGE_BASE
    local BRANCH_PATCH_ID
    local COMMIT
    local COMMIT_PATCH_ID

    MERGE_BASE="$(git merge-base "$BRANCH" "$BASE_REF")" || return 1
    BRANCH_PATCH_ID="$(_git_patch_id_for_range "$MERGE_BASE" "$BRANCH")"
    [ -n "$BRANCH_PATCH_ID" ] || return 1

    while IFS= read -r COMMIT
    do
        [ -n "$COMMIT" ] || continue
        COMMIT_PATCH_ID="$(_git_patch_id_for_commit "$COMMIT")"
        if [ "$COMMIT_PATCH_ID" = "$BRANCH_PATCH_ID" ]; then
            return 0
        fi
    done <<EOF
$(git rev-list --first-parent --no-merges "$MERGE_BASE..$BASE_REF")
EOF

    return 1
}

unalias gprune 2>/dev/null
gprune() {
    local DRY_RUN=0
    local CURRENT_BRANCH
    local DEFAULT_BRANCH
    local DEFAULT_REF
    local BRANCH
    local UPSTREAM
    local TRACK
    local DELETE_MODE
    local DELETED_COUNT=0
    local KEPT_COUNT=0

    case "${1:-}" in
        "")
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            echo "Usage: gprune [--dry-run]" >&2
            return 2
            ;;
    esac

    if [ $# -gt 0 ]; then
        echo "Usage: gprune [--dry-run]" >&2
        return 2
    fi

    git remote update origin --prune || return $?

    DEFAULT_BRANCH="$(_git_default_origin_branch)" || {
        echo "gprune: could not determine the default branch for origin." >&2
        return 1
    }
    DEFAULT_REF="origin/$DEFAULT_BRANCH"
    CURRENT_BRANCH="$(git branch --show-current)"

    while IFS='|' read -r BRANCH UPSTREAM TRACK
    do
        [ -n "$BRANCH" ] || continue

        case "$UPSTREAM" in
            origin/*)
                ;;
            *)
                continue
                ;;
        esac

        case "$TRACK" in
            *"[gone]"*)
                ;;
            *)
                continue
                ;;
        esac

        if [ "$BRANCH" = "$CURRENT_BRANCH" ]; then
            printf 'gprune: keeping %s (currently checked out)\n' "$BRANCH"
            KEPT_COUNT=$((KEPT_COUNT + 1))
            continue
        fi

        if [ "$BRANCH" = "$DEFAULT_BRANCH" ]; then
            continue
        fi

        DELETE_MODE=""
        if git merge-base --is-ancestor "$BRANCH" "$DEFAULT_REF" >/dev/null 2>&1; then
            DELETE_MODE="merged"
        elif _git_branch_matches_squash_merge "$BRANCH" "$DEFAULT_REF"; then
            DELETE_MODE="squash-merged"
        else
            printf 'gprune: keeping %s (upstream gone, but not found on %s)\n' "$BRANCH" "$DEFAULT_REF"
            KEPT_COUNT=$((KEPT_COUNT + 1))
            continue
        fi

        if [ "$DRY_RUN" -eq 1 ]; then
            printf 'gprune: would delete %s (%s into %s)\n' "$BRANCH" "$DELETE_MODE" "$DEFAULT_REF"
        else
            if [ "$DELETE_MODE" = "merged" ]; then
                git branch -d "$BRANCH" || return $?
            else
                git branch -D "$BRANCH" || return $?
            fi
            printf 'gprune: deleted %s (%s into %s)\n' "$BRANCH" "$DELETE_MODE" "$DEFAULT_REF"
        fi

        DELETED_COUNT=$((DELETED_COUNT + 1))
    done <<EOF
$(git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads)
EOF

    if [ "$DRY_RUN" -eq 1 ]; then
        printf 'gprune: %s branch(es) would be deleted.\n' "$DELETED_COUNT"
    else
        printf 'gprune: deleted %s branch(es).\n' "$DELETED_COUNT"
    fi

    if [ "$KEPT_COUNT" -gt 0 ]; then
        printf 'gprune: kept %s branch(es).\n' "$KEPT_COUNT"
    fi
}

if [ "$(uname)" != "Darwin" ]; then
    case "$TERM" in
    xterm*)
        # The following programs are known to require a Win32 Console
        # for interactive usage, therefore let's launch them through winpty
        # when run inside `mintty`.
        for name in node ipython php php5 psql python2.7 python python3
        do
            case "$(type -p "$name".exe 2>/dev/null)" in
            ''|/usr/bin/*) continue;;
            esac
            alias $name="winpty $name.exe"
        done
        ;;
    esac
fi

# make sure git completion is loaded first
if ! type __git_complete >/dev/null 2>&1 && [ -f "/mingw64/share/git/completion/git-completion.bash" ]; then
    . "/mingw64/share/git/completion/git-completion.bash"
fi

if type __git_complete >/dev/null 2>&1; then
    __git_complete ga _git_add
    __git_complete gs _git_status
    __git_complete gcp _git_cherry_pick

    __git_complete gco _git_checkout
    __git_complete gcob _git_checkout

    __git_complete gc _git_commit
    __git_complete gdc _git_diff
    __git_complete gdiff _git_diff

    __git_complete gploh _git_pull
    __git_complete gplo _git_pull
    __git_complete gplod _git_pull
    __git_complete gplos _git_pull
    __git_complete gplom _git_pull
    __git_complete gplomain _git_pull

    __git_complete gpo _git_push
    __git_complete gpoh _git_push
    __git_complete gforce _git_push

    __git_complete gst _git_stash
    __git_complete gsa _git_stash
    __git_complete gss _git_stash

    __git_complete gbr _git_branch
    __git_complete gbrd _git_branch
fi

__concat_node() {
    local TARGET_ARG="$1"
    local OUTPUT_ARG="$2"
    local CONCAT_NODE_HAS_EXCLUDES="0"
    local CONCAT_NODE_EXCLUDE_PATTERNS=""
    local PATTERN

    shift 2

    if [ "$#" -gt 0 ]; then
        CONCAT_NODE_HAS_EXCLUDES="1"
        CONCAT_NODE_EXCLUDE_PATTERNS="$1"
        shift

        for PATTERN in "$@"; do
            CONCAT_NODE_EXCLUDE_PATTERNS="${CONCAT_NODE_EXCLUDE_PATTERNS}
${PATTERN}"
        done
    fi

    CONCAT_NODE_HAS_EXCLUDES="$CONCAT_NODE_HAS_EXCLUDES" CONCAT_NODE_EXCLUDE_PATTERNS="$CONCAT_NODE_EXCLUDE_PATTERNS" command node - "$TARGET_ARG" "$OUTPUT_ARG" <<'NODE'
const { once } = require("node:events");
const fs = require("node:fs");
const fsp = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

const targetArg = process.argv[2] || ".";
const outputArg = process.argv[3] || "temp.txt";
const customExcludePatterns = process.env.CONCAT_NODE_HAS_EXCLUDES === "1"
  ? (process.env.CONCAT_NODE_EXCLUDE_PATTERNS || "").split(/\n/).map((pattern) => pattern.replace(/\r$/, ""))
  : [];
const root = path.resolve(process.cwd(), targetArg);
const outputPath = path.resolve(process.cwd(), outputArg);
const maxBytes = 2097152;
const probeBytes = 512;
const concurrency = Math.min(Math.max((typeof os.availableParallelism === "function" ? os.availableParallelism() : os.cpus().length) * 2, 8), 64);
const excludedDirectories = new Set([
  "node_modules",
  ".git",
  "dist",
  ".husky",
  "fonts",
  "target",
  "benches",
  ".github",
  "coverage",
  ".pio",
  ".vscode",
  ".idea",
  "__pycache__",
  ".venv",
  "venv",
  "build",
  "bin",
  "obj",
  ".gradle",
  ".terraform",
  ".m2",
  ".cache",
  "temp",
  "tmp",
  ".tmp",
  ".npm-cache",
  ".react-router",
  ".turbo",
  ".next",
  ".nuxt",
  ".svelte-kit",
  ".output",
  ".vercel",
  ".netlify",
  ".parcel-cache",
  ".angular",
  ".astro",
  ".cargo-home",
]);
const excludedFiles = new Set([
  "package-lock.json",
  "yarn.lock",
  "docs.schema.json",
  "LICENSE",
  ".gitignore",
  "c_cpp_properties.json",
  "launch.json",
  "settings.json",
  "Cargo.lock",
  "AGENTS.md",
  ".env",
  "pnpm-lock.yaml",
  "coverage-summary.json",
  "coverage-badge.json",
  "*.tsbuildinfo",
  "*.tsbuildinfo.json",
]);
const excludedExtensions = new Set([
  "jpg",
  "jpeg",
  "png",
  "ico",
  "webp",
  "svg",
  "gif",
  "mp4",
  "pdf",
  "exe",
  "dll",
  "bin",
  "zip",
  "tar",
  "gz",
  "iso",
]);
const internalRootFiles = new Set([
  outputArg,
  `${outputArg}.final.tmp`,
  `${outputArg}.tree.tmp`,
  `${outputArg}.excluded_dirs.tmp`,
  `${outputArg}.excluded_files.tmp`,
  `${outputArg}.contents.tmp`,
  `${outputArg}.tmp`,
  `${outputArg}.excluded`,
  `${outputArg}.tmp.tmp`,
]);
const records = [];
const candidates = [];

const fail = (message) => {
  process.stderr.write(`${message}\n`);
  process.exit(1);
};

const relPath = (fullPath) => path.relative(root, fullPath).split(path.sep).join("/");

const extTag = (name) => {
  const dot = name.lastIndexOf(".");
  if (dot === -1 || dot === name.length - 1) {
    return ["", "(noext)"];
  }
  const ext = name.slice(dot + 1).toLowerCase();
  return [ext, `.${ext}`];
};

const compileCustomExcludePattern = (rawPattern) => {
  const pattern = rawPattern.replace(/\\/g, "/").trim();
  if (!pattern) {
    fail("concat: exclude patterns cannot be empty");
  }
  if (pattern.startsWith("!")) {
    fail(`concat: negated exclude patterns are not supported: ${rawPattern}`);
  }

  let normalized = pattern;
  while (normalized.startsWith("./")) {
    normalized = normalized.slice(2);
  }

  const directoryOnly = normalized.endsWith("/");
  if (directoryOnly) {
    normalized = normalized.slice(0, -1);
  }

  const anchored = normalized.startsWith("/");
  if (anchored) {
    normalized = normalized.slice(1);
  }

  if (!normalized) {
    fail(`concat: invalid exclude pattern: ${rawPattern}`);
  }

  const glob = !anchored && !normalized.includes("/") ? `**/${normalized}` : normalized;

  return {
    directoryOnly,
    glob,
    recursiveDirectoryGlob: glob.endsWith("/**") ? glob.slice(0, -3) : null,
  };
};

const hasGlobSyntax = (pattern) => (
  pattern.includes("*") ||
  pattern.includes("?") ||
  pattern.includes("[") ||
  pattern.includes("]") ||
  pattern.includes("{") ||
  pattern.includes("}")
);

const defaultExcludedFileRules = Array.from(excludedFiles)
  .filter(hasGlobSyntax)
  .map(compileCustomExcludePattern);
const customExcludeRules = customExcludePatterns.map(compileCustomExcludePattern);

const matchesDefaultExcludedFile = (rel, name) => {
  if (excludedFiles.has(name)) {
    return true;
  }

  for (let i = 0; i < defaultExcludedFileRules.length; i += 1) {
    const rule = defaultExcludedFileRules[i];
    if (!rule.directoryOnly && path.matchesGlob(rel, rule.glob)) {
      return true;
    }
  }

  return false;
};

const matchesCustomExclude = (rel, isDirectory) => {
  for (let i = 0; i < customExcludeRules.length; i += 1) {
    const rule = customExcludeRules[i];
    if (rule.directoryOnly && !isDirectory) {
      continue;
    }
    if (path.matchesGlob(rel, rule.glob)) {
      return true;
    }
    if (isDirectory && rule.recursiveDirectoryGlob && path.matchesGlob(rel, rule.recursiveDirectoryGlob)) {
      return true;
    }
  }

  return false;
};

const readFull = async (handle, buffer, offset, length, position) => {
  let total = 0;
  while (total < length) {
    const { bytesRead } = await handle.read(buffer, offset + total, length - total, position + total);
    if (bytesRead === 0) {
      throw new Error("Unexpected end of file while reading.");
    }
    total += bytesRead;
  }
};

const walk = () => {
  const stack = [root];
  while (stack.length > 0) {
    const dir = stack.pop();
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (let i = 0; i < entries.length; i += 1) {
      const entry = entries[i];
      const fullPath = path.join(dir, entry.name);
      const rel = relPath(fullPath);
      if (entry.isDirectory()) {
        if (excludedDirectories.has(entry.name) || matchesCustomExclude(rel, true)) {
          records.push(["D", rel]);
        } else {
          records.push(["d", rel]);
          stack.push(fullPath);
        }
        continue;
      }
      if (!entry.isFile() || internalRootFiles.has(rel)) {
        continue;
      }
      const [ext, tag] = extTag(entry.name);
      if (matchesDefaultExcludedFile(rel, entry.name) || (ext && excludedExtensions.has(ext)) || matchesCustomExclude(rel, false)) {
        records.push(["x", rel, tag]);
        continue;
      }
      candidates.push([fullPath, rel, tag]);
    }
  }
};

const classify = async () => {
  const out = new Array(candidates.length);
  let next = 0;
  const workerCount = Math.min(concurrency, candidates.length);
  const workers = Array.from({ length: workerCount }, async () => {
    while (true) {
      const index = next;
      next += 1;
      if (index >= candidates.length) {
        return;
      }
      const [fullPath, rel, tag] = candidates[index];
      let handle;
      try {
        handle = await fsp.open(fullPath, "r");
        const stat = await handle.stat();
        if (!stat.isFile()) {
          out[index] = null;
          continue;
        }
        const size = Number(stat.size);
        if (maxBytes > 0 && size > maxBytes) {
          out[index] = ["x", rel, tag];
          continue;
        }
        if (size === 0) {
          out[index] = ["c", rel, tag, Buffer.alloc(0)];
          continue;
        }
        const probeLength = Math.min(size, probeBytes);
        const probe = Buffer.allocUnsafe(probeLength);
        await readFull(handle, probe, 0, probeLength, 0);
        if (probe.includes(0)) {
          out[index] = ["x", rel, tag];
          continue;
        }
        const content = Buffer.allocUnsafe(size);
        probe.copy(content, 0, 0, probeLength);
        if (size > probeLength) {
          await readFull(handle, content, probeLength, size - probeLength, probeLength);
        }
        out[index] = ["c", rel, tag, content];
      } catch {
        out[index] = ["x", rel, tag];
      } finally {
        if (handle) {
          try {
            await handle.close();
          } catch {}
        }
      }
    }
  });
  await Promise.all(workers);
  for (let i = 0; i < out.length; i += 1) {
    if (out[i]) {
      records.push(out[i]);
    }
  }
};

const countNewlines = (buffer) => {
  let count = 0;
  for (let i = 0; i < buffer.length; i += 1) {
    if (buffer[i] === 10) {
      count += 1;
    }
  }
  return count;
};

const main = async () => {
  walk();
  await classify();
  records.sort((a, b) => (a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0));

  const excludedDirPaths = [];
  const excludedFileEntries = [];
  const includedFiles = [];
  for (let i = 0; i < records.length; i += 1) {
    const record = records[i];
    if (record[0] === "D") {
      excludedDirPaths.push(record[1]);
    } else if (record[0] === "x") {
      excludedFileEntries.push([record[2], record[1]]);
    } else if (record[0] === "c") {
      includedFiles.push(record);
    }
  }

  const tempPath = `${outputPath}.concat-${process.pid}-${Date.now()}.tmp`;
  const stream = fs.createWriteStream(tempPath);
  let outputBytes = 0;
  let outputLines = 0;
  const write = async (chunk) => {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    outputBytes += buffer.length;
    outputLines += countNewlines(buffer);
    if (!stream.write(buffer)) {
      await once(stream, "drain");
    }
  };

  await write("// concatenate snapshot\n");
  await write(`// root: ${targetArg}\n`);
  await write("//\n");
  await write(`// Included files (contents copied): ${includedFiles.length}\n`);
  await write(`// Excluded files (names only):       ${excludedFileEntries.length}\n`);
  await write(`// Excluded directories (pruned):     ${excludedDirPaths.length}\n`);
  await write(`// Max file size for inclusion:       ${maxBytes} bytes (0 disables)\n`);
  await write("//\n");
  await write("// NOTE: Excluded directories are listed but NOT traversed; no child entries are present.\n\n");

  await write("// === FILE TREE (PRUNED) ===\n");
  await write("// .\n");
  for (let i = 0; i < records.length; i += 1) {
    const record = records[i];
    const rel = record[1];
    const base = rel.slice(rel.lastIndexOf("/") + 1);
    let depth = 0;
    for (let j = 0; j < rel.length; j += 1) {
      if (rel.charCodeAt(j) === 47) {
        depth += 1;
      }
    }
    const indent = " ".repeat(2 * (depth + 1));
    if (record[0] === "D") {
      await write(`// ${indent}${base}/  [excluded-dir]\n`);
    } else if (record[0] === "d") {
      await write(`// ${indent}${base}/\n`);
    } else if (record[0] === "x") {
      await write(`// ${indent}${base}  [excluded]\n`);
    } else {
      await write(`// ${indent}${base}\n`);
    }
  }
  await write("\n");

  await write("// === EXCLUDED DIRECTORIES (EXISTENCE ONLY; NOT SCANNED) ===\n");
  if (excludedDirPaths.length) {
    await write("// Listed alphabetically.\n");
    for (let i = 0; i < excludedDirPaths.length; i += 1) {
      await write(`//   - ${excludedDirPaths[i]}/\n`);
    }
  } else {
    await write("// (none)\n");
  }
  await write("\n");

  await write("// === EXCLUDED FILES (NAMES ONLY; OUTSIDE PRUNED DIRS) ===\n");
  await write("// Grouped by extension with counts.\n");
  if (excludedFileEntries.length) {
    excludedFileEntries.sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0));
    for (let i = 0; i < excludedFileEntries.length;) {
      const ext = excludedFileEntries[i][0];
      let end = i + 1;
      while (end < excludedFileEntries.length && excludedFileEntries[end][0] === ext) {
        end += 1;
      }
      if (i > 0) {
        await write("//\n");
      }
      await write(`// ${ext} (${end - i}):\n`);
      for (let j = i; j < end; j += 1) {
        await write(`//   - ${excludedFileEntries[j][1]}\n`);
      }
      i = end;
    }
  } else {
    await write("// (none)\n");
  }
  await write("\n");

  await write("// === INCLUDED FILE CONTENTS ===\n");
  for (let i = 0; i < includedFiles.length; i += 1) {
    await write(`\n// Contents of: "${includedFiles[i][1]}"\n`);
    if (includedFiles[i][3].length) {
      await write(includedFiles[i][3]);
    }
  }

  stream.end();
  await once(stream, "finish");

  try {
    await fsp.rename(tempPath, outputPath);
  } catch {
    await fsp.rm(outputPath, { force: true });
    await fsp.rename(tempPath, outputPath);
  }

  process.stderr.write(`Wrote ${outputArg}: ${(outputBytes / 1024).toFixed(2)} KB, ${outputLines} lines\n`);
};

main().catch((error) => fail(error && error.message ? error.message : String(error)));
NODE
}
