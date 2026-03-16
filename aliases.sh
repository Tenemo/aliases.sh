# https://github.com/Tenemo/aliases.sh
#
# Default location on Windows: C:\Program Files\Git\etc\profile.d\aliases.sh
# Default location on MacOS: ~/.zshrc
# After updating, run `source ~/.zshrc` (Mac) or restart terminal (Windows) to apply.

# It's aliases all the way down.
unalias aliases 2>/dev/null
aliases() {
    if [ "$(uname)" = "Darwin" ]; then
        local SRC="$HOME/.zshrc"
        if [ -f "$SRC" ]; then
            grep '^[[:space:]]*alias ' "$SRC" | sed 's/^[[:space:]]*alias[[:space:]]*//'
        else
            alias | sed 's/^alias //' | sort
        fi
    else
        local SRC="/c/Program Files/Git/etc/profile.d/aliases.sh"
        if [ -f "$SRC" ]; then
            grep '^[[:space:]]*alias ' "$SRC" | sed 's/^[[:space:]]*alias[[:space:]]*//'
        else
            alias | sed 's/^alias //' | sort
        fi
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
    local DIRECTORY_TO_SEARCH="${1:-./}"

    local OUTPUT_FILE="temp.txt"
    local TMP_FINAL="${OUTPUT_FILE}.final.tmp"
    local TMP_TREE="${OUTPUT_FILE}.tree.tmp"
    local TMP_EXCL_DIRS="${OUTPUT_FILE}.excluded_dirs.tmp"
    local TMP_EXCL_FILES="${OUTPUT_FILE}.excluded_files.tmp"
    local TMP_CONTENTS="${OUTPUT_FILE}.contents.tmp"

    if [ ! -d "$DIRECTORY_TO_SEARCH" ]; then
        echo "concat: directory not found: $DIRECTORY_TO_SEARCH" >&2
        return 2
    fi

    # ── Exclude these directories completely (existence only; DO NOT scan inside) ──
    local EXCLUDED_DIRECTORIES=(
        "node_modules" ".git" "dist" ".husky" "fonts" "target" "benches" ".github"
        "coverage" ".pio" ".vscode" ".idea" "__pycache__"
        ".venv" "venv" "build" "bin" "obj" ".gradle" ".terraform" ".m2" ".cache"
    )

    # ── Exclude specific filenames (outside excluded dirs) ──
    local EXCLUDED_FILES=(
        "package-lock.json" "yarn.lock" "LICENSE" ".gitignore"
        "c_cpp_properties.json" "launch.json" "settings.json" "Cargo.lock"
    )

    # ── Exclude extensions (outside excluded dirs) ──
    local EXCLUDED_FILE_EXTENSIONS=(
        "jpg" "jpeg" "png" "ico" "webp" "svg" "gif" "mp4" "pdf"
        "exe" "dll" "bin" "zip" "tar" "gz" "iso"
    )

    # Skip files larger than this (0 disables); size check uses stat (metadata), not reading the file
    local MAX_BYTES=$((2 * 1024 * 1024))  # 2 MiB

    # Internal files created by this function (do not include in tree/excluded lists/contents)
    # Note: only skipped when they are at repo root (REL == name).
    local INTERNAL_ROOT_FILES=(
        "$OUTPUT_FILE"
        "$TMP_FINAL" "$TMP_TREE" "$TMP_EXCL_DIRS" "$TMP_EXCL_FILES" "$TMP_CONTENTS"
        "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}.excluded" "${OUTPUT_FILE}.tmp.tmp"
    )

    # ── Fast membership sets ──
    declare -A EXCL_DIR_SET
    declare -A EXCL_FILE_SET
    declare -A EXCL_EXT_SET
    declare -A INTERNAL_ROOT_SET

    local d f e
    for d in "${EXCLUDED_DIRECTORIES[@]}"; do EXCL_DIR_SET["$d"]=1; done
    for f in "${EXCLUDED_FILES[@]}"; do EXCL_FILE_SET["$f"]=1; done
    for e in "${EXCLUDED_FILE_EXTENSIONS[@]}"; do EXCL_EXT_SET["$e"]=1; done
    for f in "${INTERNAL_ROOT_FILES[@]}"; do INTERNAL_ROOT_SET["$f"]=1; done

    # ── Helpers ──
    _file_size_bytes() {
        # echo size in bytes, metadata-only when possible
        local fp="$1" s=""
        if s=$(stat -c %s -- "$fp" 2>/dev/null); then printf '%s' "$s"; return 0; fi
        if s=$(stat -f %z -- "$fp" 2>/dev/null); then printf '%s' "$s"; return 0; fi
        wc -c < "$fp" 2>/dev/null
    }

    _indent_for_rel() {
        # prints indentation for a relative path based on depth
        local rel="$1"
        local slashes="${rel//[^\/]/}"
        local depth="${#slashes}"
        local nspaces=$((2 * (depth + 1)))
        printf '%*s' "$nspaces" ""
    }

    # ── Init temps ──
    : > "$TMP_TREE" || return 1
    : > "$TMP_EXCL_DIRS" || return 1
    : > "$TMP_EXCL_FILES" || return 1
    : > "$TMP_CONTENTS" || return 1

    # Root line for tree
    echo "// ." >> "$TMP_TREE"

    # ── Build a single find command that:
    #    - prints excluded dirs, then prunes them (so we never see their children)
    #    - prints everything else (dirs + files)
    local FIND_CMD=()
    FIND_CMD+=(find .)

    # \( -type d \( -name A -o -name B ... \) -print0 -prune \) -o -print0
    FIND_CMD+=( \( -type d \( )
    local first=1
    for d in "${EXCLUDED_DIRECTORIES[@]}"; do
        if [ $first -eq 1 ]; then
            FIND_CMD+=(-name "$d")
            first=0
        else
            FIND_CMD+=(-o -name "$d")
        fi
    done
    FIND_CMD+=( \) -print0 -prune \) -o -print0 )

    # ── Single traversal (never walks inside excluded dirs due to -prune) ──
    local included_count=0
    local excluded_file_count=0
    local pruned_dir_count=0

    while IFS= read -r -d '' ITEM; do
        # Normalize relative path (strip leading ./)
        local REL="${ITEM#./}"
        [ -z "$REL" ] && continue  # skip "."

        # Skip internal files only if they are at root (REL matches exactly)
        if [[ ${INTERNAL_ROOT_SET["$REL"]+x} ]]; then
            continue
        fi

        local FULLPATH="$DIRECTORY_TO_SEARCH/$REL"
        local INDENT; INDENT="$(_indent_for_rel "$REL")"
        local BASENAME="${REL##*/}"

        # Directory entry
        if [ -d "$FULLPATH" ]; then
            if [[ ${EXCL_DIR_SET["$BASENAME"]+x} ]]; then
                # Excluded directory: note existence, do not scan children (already pruned by find)
                echo "// ${INDENT}${BASENAME}/  [excluded-dir]" >> "$TMP_TREE"
                echo "$REL" >> "$TMP_EXCL_DIRS"
                pruned_dir_count=$((pruned_dir_count + 1))
            else
                echo "// ${INDENT}${BASENAME}/" >> "$TMP_TREE"
            fi
            continue
        fi

        # File entry
        if [ -f "$FULLPATH" ]; then
            # Determine extension (lowercase)
            local EXT=""
            if [[ "$BASENAME" == *.* ]]; then
                EXT="${BASENAME##*.}"
                EXT="${EXT,,}"
            fi
            local EXT_TAG
            if [ -n "$EXT" ]; then EXT_TAG=".$EXT"; else EXT_TAG="(noext)"; fi

            # Classify exclusion/inclusion (outside excluded dirs only, by construction)
            local REASON=""

            # excluded by exact filename
            if [[ ${EXCL_FILE_SET["$BASENAME"]+x} ]]; then
                REASON="name"
            # excluded by extension
            elif [ -n "$EXT" ] && [[ ${EXCL_EXT_SET["$EXT"]+x} ]]; then
                REASON="ext"
            # unreadable
            elif [ ! -r "$FULLPATH" ]; then
                REASON="unreadable"
            # size cap (metadata)
            elif [ "$MAX_BYTES" -gt 0 ]; then
                local SIZE; SIZE="$(_file_size_bytes "$FULLPATH")" || SIZE=0
                if [ -n "$SIZE" ] && [ "$SIZE" -gt "$MAX_BYTES" ] 2>/dev/null; then
                    REASON="size"
                fi
            fi

            # binary detection (only if not excluded yet)
            if [ -z "$REASON" ] && [ -s "$FULLPATH" ]; then
                # Fast binary sniff: grep reads minimally for empty pattern, and -I rejects binary
                if ! LC_ALL=C grep -Iq '' -- "$FULLPATH"; then
                    REASON="binary"
                fi
            fi

            if [ -n "$REASON" ]; then
                # Excluded file: record it, include only as a name in tree
                echo "// ${INDENT}${BASENAME}  [excluded]" >> "$TMP_TREE"
                printf '%s\t%s\t%s\n' "$EXT_TAG" "$REL" "$REASON" >> "$TMP_EXCL_FILES"
                excluded_file_count=$((excluded_file_count + 1))
                continue
            fi

            # Included file
            echo "// ${INDENT}${BASENAME}" >> "$TMP_TREE"
            printf '\n// Contents of: "%s"\n' "$REL" >> "$TMP_CONTENTS"
            cat -- "$FULLPATH" >> "$TMP_CONTENTS"
            included_count=$((included_count + 1))
        fi
    done < <(cd "$DIRECTORY_TO_SEARCH" && "${FIND_CMD[@]}")

    # ── Build final output (ALL in temp.txt) ──
    : > "$TMP_FINAL" || return 1

    {
        echo "// concatenate snapshot"
        echo "// root: $DIRECTORY_TO_SEARCH"
        echo "//"
        echo "// Included files (contents copied): $included_count"
        echo "// Excluded files (names only):       $excluded_file_count"
        echo "// Excluded directories (pruned):     $pruned_dir_count"
        echo "// Max file size for inclusion:       $MAX_BYTES bytes (0 disables)"
        echo "//"
        echo "// NOTE: Excluded directories are listed but NOT traversed; no child entries are present."
        echo

        echo "// === FILE TREE (PRUNED) ==="
        cat "$TMP_TREE"
        echo

        echo "// === EXCLUDED DIRECTORIES (EXISTENCE ONLY; NOT SCANNED) ==="
        if [ -s "$TMP_EXCL_DIRS" ]; then
            sort -u "$TMP_EXCL_DIRS" | sed 's#^#// - #; s#$#/#'
        else
            echo "// (none)"
        fi
        echo

        echo "// === EXCLUDED FILES (NAMES ONLY; OUTSIDE PRUNED DIRS) ==="
        echo "// Grouped by extension."
        if [ -s "$TMP_EXCL_FILES" ]; then
            # Sort by extension then path, group by extension; output ONLY paths (no reasons)
            sort -t$'\t' -k1,1 -k2,2 "$TMP_EXCL_FILES" \
              | awk -F'\t' '
                    BEGIN { cur="" }
                    {
                      ext=$1; path=$2;
                      if (ext != cur) {
                        if (cur != "") print "//"
                        cur = ext
                        print "// " cur ":"
                      }
                      print "//   " path
                    }'
        else
            echo "// (none)"
        fi
        echo

        echo "// === INCLUDED FILE CONTENTS ==="
        cat "$TMP_CONTENTS"
    } >> "$TMP_FINAL"

    mv -f "$TMP_FINAL" "$OUTPUT_FILE" || return 1

    # cleanup
    rm -f "$TMP_TREE" "$TMP_EXCL_DIRS" "$TMP_EXCL_FILES" "$TMP_CONTENTS"

    # Optional: keep terminal quiet; comment this out if you truly want zero output
    local OUTPUT_SIZE_BYTES OUTPUT_SIZE_KB OUTPUT_LINES
    OUTPUT_SIZE_BYTES="$(_file_size_bytes "$OUTPUT_FILE" 2>/dev/null)" || OUTPUT_SIZE_BYTES="?"
    OUTPUT_LINES="$(wc -l < "$OUTPUT_FILE" 2>/dev/null | tr -d '[:space:]')" || OUTPUT_LINES="?"
    [ -n "$OUTPUT_SIZE_BYTES" ] || OUTPUT_SIZE_BYTES="?"
    [ -n "$OUTPUT_LINES" ] || OUTPUT_LINES="?"
    if [ "$OUTPUT_SIZE_BYTES" = "?" ]; then
        OUTPUT_SIZE_KB="?"
    else
        OUTPUT_SIZE_KB="$(awk "BEGIN { printf \"%.2f\", $OUTPUT_SIZE_BYTES / 1024 }")"
    fi
    echo "Wrote $OUTPUT_FILE: ${OUTPUT_SIZE_KB} KB, ${OUTPUT_LINES} lines" >&2
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

alias global='npm list -g --depth 0'
alias globaloutdated='npm outdated -g --depth=0'
alias nuke_modules='rm -rf node_modules package-lock.json && npm install'
alias nuke_modules_nolock='rm -rf node_modules && npm install'
alias nuke_clean='rm -rf node_modules && npm ci' # Safer, uses lockfile exactly

alias gla='git config -l | grep alias | cut -c 7-'

alias gcl='git clone'
alias ga='git add'
alias gs='git status'
alias gcp='git cherry-pick'

alias gco='git checkout'
alias gcob='git checkout -b'
alias gcoo='git fetch && git checkout'
alias gdev='git checkout development && git pull origin development'
alias gstaging='git checkout staging && git pull origin staging'

alias gmaster='git checkout master && git pull origin master'
alias gmain='git checkout main && git pull origin main'

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
gogo() {
    [ $# -gt 0 ] || { echo "Usage: gogo <commit message>" >&2; return 2; }
    git add . && git commit -m "$*" && git push origin
}
gogogo() {
    # WARNING: This skips pre-commit hooks. Use with caution.
    [ $# -gt 0 ] || { echo "Usage: gogogo <commit message>" >&2; return 2; }
    git add . && git commit -m "$*" --no-verify && git push origin --no-verify
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
        git diff "$1" --word-diff -- ":(exclude)package-lock.json"
    else
        git diff --word-diff -- ":(exclude)package-lock.json"
    fi
}
gdiffloc() {
    if [ -n "$1" ]; then
        git diff --shortstat "$1" -- ":(exclude)package-lock.json"
    else
        git diff --shortstat -- ":(exclude)package-lock.json"
    fi
}

alias gplo='git pull origin'
alias gplod='git pull origin development'
alias gplos='git pull origin staging'
alias gplom='git pull origin master'
alias gplomain='git pull origin main'

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

alias gpo='git push origin'
alias gforce='git push origin --force-with-lease'
alias gpod='git push origin development'
alias gpos='git push origin staging'
alias gpom='git push origin master'
alias gpomain='git push origin main'
alias gpoh='git push origin HEAD'

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

alias gprune='git remote update origin --prune'

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
