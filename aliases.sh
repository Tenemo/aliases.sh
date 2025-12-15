# https://github.com/Tenemo/aliases.sh
# 
# Default location on Windows: C:\Program Files\Git\etc\profile.d\aliases.sh
# Default location on MacOS: ~/.zshrc
# After updating, run `source ~/.zshrc` (Mac) or restart terminal (Windows) to apply.

# -----------------------------------------------------------------------------
# 1. SYSTEM & UTILS
# -----------------------------------------------------------------------------

# Alias to list aliases.
if [ "$(uname)" = "Darwin" ]; then
    alias aliases="grep '^alias' ~/.zshrc | cut -d ' ' -f 2-"
else
    # Tries to find the file in the default git path
    alias aliases="grep '^alias' '/c/Program Files/Git/etc/profile.d/aliases.sh' | cut -d ' ' -f 2-"
fi

# --show-control-chars: help showing Korean or accented characters
if [ "$(uname)" = "Darwin" ]; then
    alias ls='ls -F -G'
else
    alias ls='ls -F --color=auto --show-control-chars'
fi
alias ll='ls -l'

# For working with LLMs (Optimized for speed)
concatenate() {
    DIRECTORY_TO_SEARCH="${1:-./}" # Default to current dir, can accept arg
    OUTPUT_FILE="temp.txt"
    
    # Exclude these directories completely (prune) to save massive time
    EXCLUDED_DIRECTORIES=("node_modules" ".git" "dist" ".husky" "fonts" "target" "benches" ".github" "coverage" ".pio" ".vscode" ".idea" "__pycache__")
    # Exclude specific filenames
    EXCLUDED_FILES=("$OUTPUT_FILE" "package-lock.json" "yarn.lock" "LICENSE" ".gitignore" "c_cpp_properties.json" "launch.json" "settings.json" "Cargo.lock")
    # Exclude extensions (Case insensitive)
    EXCLUDED_FILE_EXTENSIONS=("jpg" "jpeg" "png" "ico" "webp" "svg" "gif" "mp4" "pdf" "exe" "dll" "bin" "zip" "tar" "gz" "iso")
    
    # Build the find command using an array to handle spaces and special chars safely
    FIND_CMD=(find "$DIRECTORY_TO_SEARCH")

    # 1. Prune directories (Do not enter them)
    for DIR in "${EXCLUDED_DIRECTORIES[@]}"; do
        FIND_CMD+=(-name "$DIR" -prune -o)
    done

    # 2. Look for files
    FIND_CMD+=(-type f)

    # 3. Exclude specific files
    for EXCLUDE in "${EXCLUDED_FILES[@]}"; do
        FIND_CMD+=(! -name "$EXCLUDE")
    done

    # 4. Exclude extensions (using -iname for case insensitivity)
    for EXT in "${EXCLUDED_FILE_EXTENSIONS[@]}"; do
        FIND_CMD+=(! -iname "*.$EXT")
    done

    # 5. Print valid files
    FIND_CMD+=(-print)

    # Prepare temp file
    TEMP_OUT="${OUTPUT_FILE}.tmp"
    > "$TEMP_OUT"

    echo "Scanning directory..."

    # Execute find and loop
    "${FIND_CMD[@]}" | while IFS= read -r FILE; do
        # Check if file is binary (grep -I checks for binary, returns 0 if text)
        if grep -Iq . "$FILE"; then
            echo -e "\n// Contents of: \"${FILE#./}\":" >> "$TEMP_OUT"
            cat "$FILE" >> "$TEMP_OUT"
        fi
    done

    # Move temp to final
    mv "$TEMP_OUT" "$OUTPUT_FILE"

    # Stats
    if [ "$(uname)" = "Darwin" ]; then
        FILE_SIZE_BYTES=$(stat -f %z "$OUTPUT_FILE")
    else
        FILE_SIZE_BYTES=$(stat -c %s "$OUTPUT_FILE")
    fi
    
    FILE_SIZE_KB=$(awk "BEGIN {printf \"%.2f\", $FILE_SIZE_BYTES/1024}")
    LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
    echo "Concatenation successful. Output file: $OUTPUT_FILE (Size: $FILE_SIZE_KB KB, Lines: $LINE_COUNT)"
}

# -----------------------------------------------------------------------------
# 2. NPM
# -----------------------------------------------------------------------------
# Scripts
alias i='npm install'
alias s='npm start || npm run dev'
alias r='npm run'
alias b='npm run build'
alias d='npm run deploy'
alias bs='npm run build:skip'
alias t='npm test'
alias u='npm test -- -u'
alias od='npm outdated'
alias up='npm update'
alias un='npm uninstall'

# Updates
alias cu='ncu --packageFile package.json'
alias cuu='ncu --packageFile package.json -u && rm -rf package-lock.json node_modules && npm install'
alias cxuu='ncu --packageFile package.json -u -x "history" && rm -rf package-lock.json node_modules && npm install'
alias cruu='ncu --packageFile package.json -u -x react,react-dom  && rm -rf package-lock.json node_modules && npm install'

# Packages / Maintenance
alias global='npm list -g --depth 0'
alias globaloutdated='npm outdated -g --depth=0'
alias nuke_modules='rm -rf node_modules package-lock.json && npm install'
alias nuke_modules_nolock='rm -rf node_modules && npm install'
alias nuke_clean='rm -rf node_modules && npm ci' # Safer, uses lockfile exactly

# -----------------------------------------------------------------------------
# 3. GIT
# -----------------------------------------------------------------------------
# List all git aliases
alias gla='git config -l | grep alias | cut -c 7-'

# General
alias gcl='git clone'
alias ga='git add'
alias gs='git status'
alias gcp='git cherry-pick'

# Checkout
alias gco='git checkout'
alias gcob='git checkout -b'
alias gcoo='git fetch && git checkout'
alias gdev='git checkout development && git pull origin development'
alias gstaging='git checkout staging && git pull origin staging'

# Master / Main Handling
alias gmaster='git checkout master && git pull origin master'
alias gmain='git checkout main && git pull origin main'

# Commit
alias gc='git commit'
alias gamend='git commit --amend --no-edit'
alias gaamend='git add . && git commit --amend --no-edit'
gcm() {
    git commit -m"$1"
}
gac() {
    git add . && git commit -m"$1"
}
gacgo() {
    git add . && git commit -m"$1" --no-verify
}
gogo() {
    git add . && git commit -m"$1" && git push origin
}
gogogo() {
    # WARNING: This skips pre-commit hooks. Use with caution.
    git add . && git commit -m"$1" --no-verify && git push origin --no-verify
}

# Helpers
listall() {
	find . ! -path "./node_modules/*" ! -path "./.git/*" ! -path "./.husky/*" -type f -print | sed 's|^\./||'
}

# Branch
alias gbr='git branch'
alias gbrd='git branch -d'

# Diff
alias gdlc='git diff --cached HEAD^ -- ":(exclude)package-lock.json"'
gdc() {
    git diff $1 --cached -- ":(exclude)package-lock.json"
}
gdiff() {
    git diff $1 --word-diff -- ":(exclude)package-lock.json"
}
gdiffloc() {
    git diff --shortstat $1 -- ":(exclude)package-lock.json"
}

# Pull
alias gplo='git pull origin'
alias gplod='git pull origin development'
alias gplos='git pull origin staging'
alias gplom='git pull origin master'
alias gplomain='git pull origin main'
alias gploh='git pull origin HEAD'

# Push
alias gpo='git push origin'
alias gforce='git push origin --force-with-lease'
alias gpod='git push origin development'
alias gpos='git push origin staging'
alias gpom='git push origin master'
alias gpomain='git push origin main'
alias gpoh='git push origin HEAD'

# Reset
alias gr='git reset'
alias gr1='git reset HEAD^'
alias gr2='git reset HEAD^^'
alias grh='git reset --hard'
alias grh1='git reset HEAD^ --hard'
alias grh2='git reset HEAD^^ --hard'
alias gunstage='git reset --soft HEAD^'

# Stash
alias gst='git stash'
alias gsl='git stash list'
alias gsa='git stash apply'
alias gss='git stash save'

# Log
alias ggr='git log --graph --full-history --all --color --pretty=tformat:"%x1b[31m%h%x09%x1b[32m%d%x1b[0m%x20%s%x20%x1b[33m(%an)%x1b[0m"'
alias gls='git log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate'
alias gll='git log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate --numstat'
alias gld='git log --pretty=format:"%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate --date=relative'
alias glds='git log --pretty=format:"%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate --date=short'
alias gdl='git ll -1'

# Remote
alias gprune='git remote update origin --prune'

# -----------------------------------------------------------------------------
# 4. WINDOWS COMPATIBILITY (Winpty)
# -----------------------------------------------------------------------------
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