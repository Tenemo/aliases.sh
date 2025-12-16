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
concatenate() {
    DIRECTORY_TO_SEARCH="${1:-./}"   # Default to current dir, can accept arg
    OUTPUT_FILE="temp.txt"
    TEMP_OUT="${OUTPUT_FILE}.tmp"

    if [ ! -d "$DIRECTORY_TO_SEARCH" ]; then
        echo "concatenate: directory not found: $DIRECTORY_TO_SEARCH" >&2
        return 2
    fi

    # Exclude these directories completely
    EXCLUDED_DIRECTORIES=(
        "node_modules" ".git" "dist" ".husky" "fonts" "target" "benches" ".github"
        "coverage" ".pio" ".vscode" ".idea" "__pycache__"
    )

    # Exclude specific filenames
    EXCLUDED_FILES=(
        "$OUTPUT_FILE" "$TEMP_OUT"
        "package-lock.json" "yarn.lock" "LICENSE" ".gitignore"
        "c_cpp_properties.json" "launch.json" "settings.json" "Cargo.lock"
    )

    # Exclude extensions (case-insensitive via -iname)
    EXCLUDED_FILE_EXTENSIONS=(
        "jpg" "jpeg" "png" "ico" "webp" "svg" "gif" "mp4" "pdf"
        "exe" "dll" "bin" "zip" "tar" "gz" "iso"
    )

    FIND_CMD=(find "$DIRECTORY_TO_SEARCH")

    for DIR in "${EXCLUDED_DIRECTORIES[@]}"; do
        FIND_CMD+=(-type d -name "$DIR" -prune -o)
    done

    FIND_CMD+=(-type f)

    for EXCLUDE in "${EXCLUDED_FILES[@]}"; do
        FIND_CMD+=(-not -name "$EXCLUDE")
    done

    for EXT in "${EXCLUDED_FILE_EXTENSIONS[@]}"; do
        FIND_CMD+=(-not -iname "*.$EXT")
    done

    FIND_CMD+=(-print)

    : > "$TEMP_OUT"

    echo "Scanning directory: $DIRECTORY_TO_SEARCH"

    "${FIND_CMD[@]}" | while IFS= read -r FILE; do
        # Include empty files; skip binary files
        if [ ! -s "$FILE" ] || grep -Iq . "$FILE"; then
            printf '\n// Contents of: "%s":\n' "${FILE#./}" >> "$TEMP_OUT"
            cat "$FILE" >> "$TEMP_OUT"
        fi
    done

    mv "$TEMP_OUT" "$OUTPUT_FILE"

    if [ "$(uname)" = "Darwin" ]; then
        FILE_SIZE_BYTES=$(stat -f %z "$OUTPUT_FILE" 2>/dev/null || wc -c < "$OUTPUT_FILE")
    else
        FILE_SIZE_BYTES=$(stat -c %s "$OUTPUT_FILE" 2>/dev/null || wc -c < "$OUTPUT_FILE")
    fi

    FILE_SIZE_KB=$(awk "BEGIN {printf \"%.2f\", $FILE_SIZE_BYTES/1024}")
    LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
    echo "Concatenation successful. Output file: $OUTPUT_FILE (Size: $FILE_SIZE_KB KB, Lines: $LINE_COUNT)"
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
