# https://github.com/Tenemo/aliases.sh
# Default location on Windows: C:\Program Files\Git\etc\profile.d\aliases.sh
# I left the default contents in place.

# Alias to list aliases. It's aliases all the way down.
alias aliases="grep '^alias' 'C:/Program Files/Git/etc/profile.d/aliases.sh' | cut -d ' ' -f 2-"

# For working with LLMs
concatenate() {
    DIRECTORY_TO_SEARCH="./"
    OUTPUT_FILE="concatenated.txt"
    if [ -f "$OUTPUT_FILE" ]; then
        rm "$OUTPUT_FILE"
    fi
    EXCLUDED_DIRECTORIES=("node_modules" ".git" "dist" ".husky" "fonts" "target" "benches" ".github")
    EXCLUDED_FILES=("$OUTPUT_FILE" "package-lock.json" "LICENSE" ".gitignore")
    EXCLUDED_FILE_EXTENSIONS=("jpg" "jpeg" "JPG" "JPEG" "png" "PNG")
    FIND_EXCLUSIONS=()
    
    # Handle specific file names by excluding them directly
    for EXCLUDE in "${EXCLUDED_FILES[@]}"; do
        FIND_EXCLUSIONS+=(! -name "$EXCLUDE")
    done

    # Handle directory exclusions at any level
    for DIR in "${EXCLUDED_DIRECTORIES[@]}"; do
        FIND_EXCLUSIONS+=(! -path "*/${DIR}/*")
    done

    # Exclude files based on extensions
    for EXT in "${EXCLUDED_FILE_EXTENSIONS[@]}"; do
        FIND_EXCLUSIONS+=(! -iname "*.$EXT")
    done

    while IFS= read -r FILE; do
        # Remove leading './', add newline, and add header with file name including quotes
        echo -e "\n// Contents of: \"${FILE#./}\":" >> "$OUTPUT_FILE"
        cat "$FILE" >> "$OUTPUT_FILE"
    done < <(find "$DIRECTORY_TO_SEARCH" -type f "${FIND_EXCLUSIONS[@]}")


    # After concatenation, calculate file size in kilobytes (rounded to two decimal places)
    FILE_SIZE_KB=$(awk "BEGIN {printf \"%.2f\", $(stat -c %s "$OUTPUT_FILE")/1024}")

    # Count the number of lines in the output file
    LINE_COUNT=$(wc -l < "$OUTPUT_FILE")

    echo "Concatenation successful. Output file: $OUTPUT_FILE (Size: $FILE_SIZE_KB KB, Lines: $LINE_COUNT)"
}

# --show-control-chars: help showing Korean or accented characters
alias ls='ls -F --color=auto --show-control-chars'
alias ll='ls -l'

# NPM

# scripts
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
alias cu='ncu --packageFile package.json'
alias cuu='ncu --packageFile package.json -u && rm -rf package-lock.json node_modules && npm install'
alias cxuu='ncu --packageFile package.json -u -x "history" && rm -rf package-lock.json node_modules && npm install'
alias cruu='ncu --packageFile package.json -u -x react,react-dom  && rm -rf package-lock.json node_modules && npm install'

# packages
alias global='npm list -g --depth 0'
alias globaloutdated='npm outdated -g --depth=0'
alias nuke_modules='rm -rf node_modules package-lock.json && npm install'
alias nuke_modules_nolock='rm -rf node_modules && npm install'

# GIT

# list all git aliases
alias gla='git config -l | grep alias | cut -c 7-'

# git general
alias gcl='git clone'
alias ga='git add'
alias gs='git status'
alias gcp='git cherry-pick'

# git checkout
alias gco='git checkout'
alias gcob='git checkout -b'
alias gcoo='git fetch && git checkout'
alias gdev='git checkout development && git pull origin development'
alias gstaging='git checkout staging && git pull origin staging'
alias gmaster='git checkout master && git pull origin'
alias gmain='git checkout main && git pull origin'

mainsync() {
	CURRENT_BRANCH=$(git rev-parse --abbrev-ref @)
	git checkout main && git pull origin && npm run hasura:migrate:apply && npm run hasura:metadata:apply && git checkout ${CURRENT_BRANCH}
}


# git commit
alias gc='git commit'
alias gamend='git commit --amend --no-edit'
alias gaamend='git add . && git commit --amend --no-edit'
gcm() {
    git commit -m"$1"
}
gac() {
    git add . && git commit -m"$1"
}
gogo() {
    git add . && git commit -m"$1" && git push origin
}
gogogo() {
    git add . && git commit -m"$1" --no-verify && git push origin --no-verify
}

listall() {
	find . ! -path "./node_modules/*" ! -path "./.git/*" ! -path "./.husky/*" -type f -print | sed 's|^\./||'
}

#git branch
alias gbr='git branch'
alias gbrd='git branch -d'

#git diff
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

#git pull
alias gplo='git pull origin'
alias gplod='git pull origin development'
alias gplos='git pull origin staging'
alias gplom='git pull origin master'
alias gploh='git pull origin HEAD'

#git push
alias gpo='git push origin'
alias gforce='git push origin --force-with-lease'
alias gpod='git push origin development'
alias gpos='git push origin staging'
alias gpom='git push origin master'
alias gpoh='git push origin HEAD'

#git reset
alias gr='git reset'
alias gr1='git reset HEAD^'
alias gr2='git reset HEAD^^'
alias grh='git reset --hard'
alias grh1='git reset HEAD^ --hard'
alias grh2='git reset HEAD^^ --hard'
alias gunstage='git reset --soft HEAD^'

#git stash
alias gst='git stash'
alias gsl='git stash list'
alias gsa='git stash apply'
alias gss='git stash save'

# git log
alias ggr='git log --graph --full-history --all --color --pretty=tformat:"%x1b[31m%h%x09%x1b[32m%d%x1b[0m%x20%s%x20%x1b[33m(%an)%x1b[0m"'
alias gls='git log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate'
alias gll='git log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate --numstat'
alias gld='git log --pretty=format:"%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate --date=relative'
alias glds='git log --pretty=format:"%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cgreen\\ [%cn]" --decorate --date=short'
alias gdl='git ll -1'

# git remote
alias gprune='git remote update origin --prune'

case "$TERM" in
xterm*)
    # The following programs are known to require a Win32 Console
    # for interactive usage, therefore let's launch them through winpty
    # when run inside `mintty`.
    for name in node ipython php php5 psql python2.7
    do
        case "$(type -p "$name".exe 2>/dev/null)" in
        ''|/usr/bin/*) continue;;
        esac
        alias $name="winpty $name.exe"
    done
    ;;
esac
