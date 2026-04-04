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
    if [ ! -d "$DIRECTORY_TO_SEARCH" ]; then
        echo "concat: directory not found: $DIRECTORY_TO_SEARCH" >&2
        return 2
    fi

    local TMP_ROOT
    TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/concat.XXXXXX")" || return 1
    local TMP_FINAL="$TMP_ROOT/final.tmp"
    local TMP_TREE="$TMP_ROOT/tree.tmp"
    local TMP_EXCL_DIRS="$TMP_ROOT/excluded_dirs.tmp"
    local TMP_EXCL_FILES="$TMP_ROOT/excluded_files.tmp"
    local TMP_CONTENTS="$TMP_ROOT/contents.tmp"
    local TMP_RECORDS="$TMP_ROOT/records.tmp"
    local TMP_CANDIDATE_PATHS="$TMP_ROOT/candidate_paths.tmp"
    local TMP_INCLUDED_FILES="$TMP_ROOT/included_files.tmp"
    local TMP_GREP_PROBE="$TMP_ROOT/grep-probe.tmp"

    # Exclude these directories completely (existence only; do not scan inside)
    local EXCLUDED_DIRECTORIES=(
        "node_modules" ".git" "dist" ".husky" "fonts" "target" "benches" ".github"
        "coverage" ".pio" ".vscode" ".idea" "__pycache__"
        ".venv" "venv" "build" "bin" "obj" ".gradle" ".terraform" ".m2" ".cache"
		"temp" ".npm-cache" ".react-router"
    )

    # Exclude specific filenames (outside excluded dirs)
    local EXCLUDED_FILES=(
        "package-lock.json" "yarn.lock" "LICENSE" ".gitignore"
        "c_cpp_properties.json" "launch.json" "settings.json" "Cargo.lock"
		"AGENTS.md" ".env" "pnpm-lock.yaml"
    )

    # Exclude extensions (outside excluded dirs)
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
        "${OUTPUT_FILE}.final.tmp" "${OUTPUT_FILE}.tree.tmp"
        "${OUTPUT_FILE}.excluded_dirs.tmp" "${OUTPUT_FILE}.excluded_files.tmp" "${OUTPUT_FILE}.contents.tmp"
        "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}.excluded" "${OUTPUT_FILE}.tmp.tmp"
    )

    # Fast membership sets
    declare -A EXCL_DIR_SET
    declare -A EXCL_FILE_SET
    declare -A EXCL_EXT_SET
    declare -A INTERNAL_ROOT_SET

    local d f e
    for d in "${EXCLUDED_DIRECTORIES[@]}"; do EXCL_DIR_SET["$d"]=1; done
    for f in "${EXCLUDED_FILES[@]}"; do EXCL_FILE_SET["$f"]=1; done
    for e in "${EXCLUDED_FILE_EXTENSIONS[@]}"; do EXCL_EXT_SET["$e"]=1; done
    for f in "${INTERNAL_ROOT_FILES[@]}"; do INTERNAL_ROOT_SET["$f"]=1; done

    # Helpers
    _file_size_bytes() {
        # echo size in bytes, metadata-only when possible
        local fp="$1" s=""
        if s=$(stat -c %s -- "$fp" 2>/dev/null); then printf '%s' "$s"; return 0; fi
        if s=$(stat -f %z -- "$fp" 2>/dev/null); then printf '%s' "$s"; return 0; fi
        wc -c < "$fp" 2>/dev/null
    }

    _concat_cleanup() {
        rm -rf -- "$TMP_ROOT"
    }

    # Init temps
    : > "$TMP_TREE" || { _concat_cleanup; return 1; }
    : > "$TMP_EXCL_DIRS" || { _concat_cleanup; return 1; }
    : > "$TMP_EXCL_FILES" || { _concat_cleanup; return 1; }
    : > "$TMP_CONTENTS" || { _concat_cleanup; return 1; }
    : > "$TMP_RECORDS" || { _concat_cleanup; return 1; }
    : > "$TMP_CANDIDATE_PATHS" || { _concat_cleanup; return 1; }
    : > "$TMP_INCLUDED_FILES" || { _concat_cleanup; return 1; }

    exec 3>"$TMP_TREE" 4>"$TMP_EXCL_DIRS" 5>"$TMP_EXCL_FILES" 6>"$TMP_INCLUDED_FILES"

    # Root line for tree
    printf '%s\n' "// ." >&3

    # Build a single find command that:
    #    - prints excluded dirs, then prunes them (so we never see their children)
    #    - prints everything else (dirs + files)
    local FIND_CMD=()
    FIND_CMD+=(find .)
    FIND_CMD+=( \( -type d \( )
    local first=1
    for d in "${EXCLUDED_DIRECTORIES[@]}"; do
        if [ "$first" -eq 1 ]; then
            FIND_CMD+=(-name "$d")
            first=0
        else
            FIND_CMD+=(-o -name "$d")
        fi
    done

    local FIND_SUPPORTS_PRINTF=0
    if (cd "$DIRECTORY_TO_SEARCH" && find . -maxdepth 0 -printf '' >/dev/null 2>&1); then
        FIND_SUPPORTS_PRINTF=1
    fi

    if [ "$FIND_SUPPORTS_PRINTF" -eq 1 ]; then
        FIND_CMD+=( \) -printf '%P\tD\t0\0' -prune \) -o -printf '%P\t%y\t%s\0' )
    else
        FIND_CMD+=( \) -print0 -prune \) -o -print0 )
    fi

    local ITEM REL TYPE SIZE BASENAME FULLPATH EXT EXT_TAG REASON

    if [ "$FIND_SUPPORTS_PRINTF" -eq 1 ]; then
        while IFS= read -r -d '' ITEM; do
            IFS=$'\t' read -r REL TYPE SIZE <<< "$ITEM"
            [ -z "$REL" ] && continue

            BASENAME="${REL##*/}"
            FULLPATH="$DIRECTORY_TO_SEARCH/$REL"
            SIZE="${SIZE:-0}"

            if [ "$TYPE" = "D" ]; then
                printf 'D\t%s\n' "$REL" >> "$TMP_RECORDS"
                continue
            fi

            if [ "$TYPE" != "f" ] && [ "$TYPE" != "d" ]; then
                continue
            fi

            if [ "$TYPE" = "d" ]; then
                printf 'd\t%s\n' "$REL" >> "$TMP_RECORDS"
                continue
            fi

            if [[ ${INTERNAL_ROOT_SET["$REL"]+x} ]]; then
                continue
            fi

            EXT=""
            if [[ "$BASENAME" == *.* ]]; then
                EXT="${BASENAME##*.}"
                EXT="${EXT,,}"
            fi
            if [ -n "$EXT" ]; then EXT_TAG=".$EXT"; else EXT_TAG="(noext)"; fi

            REASON=""
            if [[ ${EXCL_FILE_SET["$BASENAME"]+x} ]]; then
                REASON="name"
            elif [ -n "$EXT" ] && [[ ${EXCL_EXT_SET["$EXT"]+x} ]]; then
                REASON="ext"
            elif [ ! -r "$FULLPATH" ]; then
                REASON="unreadable"
            elif [ "$MAX_BYTES" -gt 0 ] && [ -n "$SIZE" ] && [ "$SIZE" -gt "$MAX_BYTES" ] 2>/dev/null; then
                REASON="size"
            fi

            if [ -n "$REASON" ]; then
                printf 'x\t%s\t%s\t%s\n' "$REL" "$EXT_TAG" "$REASON" >> "$TMP_RECORDS"
                continue
            fi

            printf 'c\t%s\t%s\t%s\n' "$REL" "$EXT_TAG" "$FULLPATH" >> "$TMP_RECORDS"
            if [ "$SIZE" -gt 0 ] 2>/dev/null; then
                printf '%s\0' "$FULLPATH" >> "$TMP_CANDIDATE_PATHS"
            fi
        done < <(cd "$DIRECTORY_TO_SEARCH" && "${FIND_CMD[@]}")
    else
        while IFS= read -r -d '' ITEM; do
            REL="${ITEM#./}"
            [ -z "$REL" ] && continue

            BASENAME="${REL##*/}"
            FULLPATH="$DIRECTORY_TO_SEARCH/$REL"
            SIZE=0

            if [ -d "$FULLPATH" ]; then
                if [[ ${EXCL_DIR_SET["$BASENAME"]+x} ]]; then
                    printf 'D\t%s\n' "$REL" >> "$TMP_RECORDS"
                else
                    printf 'd\t%s\n' "$REL" >> "$TMP_RECORDS"
                fi
                continue
            fi

            if [ ! -f "$FULLPATH" ]; then
                continue
            fi

            if [[ ${INTERNAL_ROOT_SET["$REL"]+x} ]]; then
                continue
            fi

            EXT=""
            if [[ "$BASENAME" == *.* ]]; then
                EXT="${BASENAME##*.}"
                EXT="${EXT,,}"
            fi
            if [ -n "$EXT" ]; then EXT_TAG=".$EXT"; else EXT_TAG="(noext)"; fi

            REASON=""
            if [[ ${EXCL_FILE_SET["$BASENAME"]+x} ]]; then
                REASON="name"
            elif [ -n "$EXT" ] && [[ ${EXCL_EXT_SET["$EXT"]+x} ]]; then
                REASON="ext"
            elif [ ! -r "$FULLPATH" ]; then
                REASON="unreadable"
            else
                SIZE="$(_file_size_bytes "$FULLPATH")" || SIZE=0
            fi

            if [ -z "$REASON" ] && [ "$MAX_BYTES" -gt 0 ]; then
                if [ -n "$SIZE" ] && [ "$SIZE" -gt "$MAX_BYTES" ] 2>/dev/null; then
                    REASON="size"
                fi
            fi

            if [ -n "$REASON" ]; then
                printf 'x\t%s\t%s\t%s\n' "$REL" "$EXT_TAG" "$REASON" >> "$TMP_RECORDS"
                continue
            fi

            printf 'c\t%s\t%s\t%s\n' "$REL" "$EXT_TAG" "$FULLPATH" >> "$TMP_RECORDS"
            if [ "$SIZE" -gt 0 ] 2>/dev/null; then
                printf '%s\0' "$FULLPATH" >> "$TMP_CANDIDATE_PATHS"
            fi
        done < <(cd "$DIRECTORY_TO_SEARCH" && "${FIND_CMD[@]}")
    fi

    declare -A BINARY_FILE_SET
    local CAN_BATCH_BINARY=0
    : > "$TMP_GREP_PROBE"
    if grep -ILZ '' -- "$TMP_GREP_PROBE" >/dev/null 2>&1; then
        CAN_BATCH_BINARY=1
    fi

    if [ -s "$TMP_CANDIDATE_PATHS" ]; then
        if [ "$CAN_BATCH_BINARY" -eq 1 ]; then
            while IFS= read -r -d '' FULLPATH; do
                BINARY_FILE_SET["$FULLPATH"]=1
            done < <(xargs -0 grep -ILZ '' < "$TMP_CANDIDATE_PATHS" 2>/dev/null || true)
        else
            while IFS= read -r -d '' FULLPATH; do
                if [ -s "$FULLPATH" ] && ! LC_ALL=C grep -Iq '' -- "$FULLPATH"; then
                    BINARY_FILE_SET["$FULLPATH"]=1
                fi
            done < "$TMP_CANDIDATE_PATHS"
        fi
    fi

    local included_count=0
    local excluded_file_count=0
    local pruned_dir_count=0
    local SLASHES DEPTH INDENT RECORD_TYPE RECORD_EXT_TAG RECORD_REASON

    while IFS=$'\t' read -r RECORD_TYPE REL RECORD_EXT_TAG RECORD_REASON; do
        [ -z "$RECORD_TYPE" ] && continue

        BASENAME="${REL##*/}"
        SLASHES="${REL//[^\/]/}"
        DEPTH="${#SLASHES}"
        printf -v INDENT '%*s' "$((2 * (DEPTH + 1)))" ""

        if [ "$RECORD_TYPE" = "D" ]; then
            printf '// %s%s/  [excluded-dir]\n' "$INDENT" "$BASENAME" >&3
            printf '%s\n' "$REL" >&4
            pruned_dir_count=$((pruned_dir_count + 1))
            continue
        fi

        if [ "$RECORD_TYPE" = "d" ]; then
            printf '// %s%s/\n' "$INDENT" "$BASENAME" >&3
            continue
        fi

        if [ "$RECORD_TYPE" = "c" ]; then
            FULLPATH="$RECORD_REASON"
            if [[ ${BINARY_FILE_SET["$FULLPATH"]+x} ]]; then
                RECORD_TYPE="x"
                RECORD_REASON="binary"
            fi
        fi

        if [ "$RECORD_TYPE" = "x" ]; then
            printf '// %s%s  [excluded]\n' "$INDENT" "$BASENAME" >&3
            printf '%s\t%s\t%s\n' "$RECORD_EXT_TAG" "$REL" "$RECORD_REASON" >&5
            excluded_file_count=$((excluded_file_count + 1))
            continue
        fi

        printf '// %s%s\n' "$INDENT" "$BASENAME" >&3
        printf '%s\n' "$REL" >&6
        included_count=$((included_count + 1))
    done < "$TMP_RECORDS"

    exec 3>&- 4>&- 5>&- 6>&-

    : > "$TMP_CONTENTS" || { _concat_cleanup; return 1; }
    if [ -s "$TMP_INCLUDED_FILES" ]; then
        if command -v perl >/dev/null 2>&1; then
            (
                cd "$DIRECTORY_TO_SEARCH" || exit 1
                perl -ne '
                    BEGIN { binmode STDOUT; }
                    chomp;
                    $rel = $_;
                    print qq{\n// Contents of: "$rel"\n};
                    open my $fh, "<", $rel or next;
                    binmode $fh;
                    while (read $fh, my $buf, 65536) {
                        print $buf;
                    }
                    close $fh;
                ' "$TMP_INCLUDED_FILES"
            ) > "$TMP_CONTENTS"
        else
            (
                cd "$DIRECTORY_TO_SEARCH" || exit 1
                while IFS= read -r REL; do
                    printf '\n// Contents of: "%s"\n' "$REL"
                    cat -- "$REL"
                done < "$TMP_INCLUDED_FILES"
            ) > "$TMP_CONTENTS"
        fi
    fi

    # Build final output (all in temp.txt)
    : > "$TMP_FINAL" || { _concat_cleanup; return 1; }

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

    mv -f "$TMP_FINAL" "$OUTPUT_FILE" || { _concat_cleanup; return 1; }

    # cleanup
    _concat_cleanup

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

alias pnpmup='pnpm -r up --latest && pnpm install --force'

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

unalias gpo 2>/dev/null
gpo() {
    _git_push_origin_current
}
unalias gforce 2>/dev/null
gforce() {
    _git_push_origin_current --force-with-lease
}
alias gpod='git push origin development'
alias gpos='git push origin staging'
alias gpom='git push origin master'
alias gpomain='git push origin main'
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

# make sure git completion is loaded first
type __git_complete >/dev/null 2>&1 || \
    . "/mingw64/share/git/completion/git-completion.bash"

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
