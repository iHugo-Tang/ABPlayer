#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PROJECT_FILE="Project.swift"
CHANGELOG_FILE="CHANGELOG.md"
STATE_FILE=".release_state"

# Centralized commit filter - commits matching these patterns will be excluded from changelog
EXCLUDED_COMMIT_PATTERNS="^ci\(release_sh\):"

if [ ! -f "$PROJECT_FILE" ]; then
    echo -e "${RED}Error: $PROJECT_FILE not found!${NC}"
    exit 1
fi

# 1. Update Build Version (Always increments)
echo "Reading current build version..."
CURRENT_BUILD=$(grep 'let buildVersionString' "$PROJECT_FILE" | sed -E 's/.*"([0-9]+)".*/\1/')
NEW_BUILD=$((CURRENT_BUILD + 1))
echo "Incrementing build version: $CURRENT_BUILD -> $NEW_BUILD"

sed -i '' "s/let buildVersionString = \"$CURRENT_BUILD\"/let buildVersionString = \"$NEW_BUILD\"/" "$PROJECT_FILE"

# 2. Update Short Version (Only if argument provided)
if [ -n "$1" ]; then
    NEW_VERSION="$1"
    echo "Updating short version to: $NEW_VERSION"
    sed -i '' "s/let shortVersionString = \".*\"/let shortVersionString = \"$NEW_VERSION\"/" "$PROJECT_FILE"
else
    # Read existing short version
    NEW_VERSION=$(grep 'let shortVersionString' "$PROJECT_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
    echo "No version specified. Keeping existing short version: $NEW_VERSION"
fi

# 3. Generate Changelog
echo "Generating changelog for version $NEW_VERSION..."

DATE=$(date +%Y-%m-%d)
FULL_VERSION="${NEW_VERSION}.${NEW_BUILD}"
HEADER="## [$FULL_VERSION] - $DATE"

# Determine commit range
if [ -f "$STATE_FILE" ]; then
    LAST_COMMIT=$(cat "$STATE_FILE")
    echo "Found last release commit: $LAST_COMMIT"
    # Check if the commit actually exists
    if git cat-file -e "$LAST_COMMIT" 2>/dev/null; then
        COMMITS=$(git log --pretty=format:"%s" "$LAST_COMMIT..HEAD" | grep -vE "$EXCLUDED_COMMIT_PATTERNS")
    else
        echo -e "${RED}Warning: Last commit $LAST_COMMIT not found. Defaulting to last 10 commits.${NC}"
        COMMITS=$(git log -n 10 --pretty=format:"%s" | grep -vE "$EXCLUDED_COMMIT_PATTERNS")
    fi
else
    echo "No previous release state found. Defaulting to last 10 commits."
    COMMITS=$(git log -n 10 --pretty=format:"%s" | grep -vE "$EXCLUDED_COMMIT_PATTERNS")
fi

# Initialize category arrays
FEATURES=""
FIXES=""
IMPROVEMENTS=""
CHORES=""
OTHER=""

# Categorize commits
while IFS= read -r commit; do
    if [ -z "$commit" ]; then
        continue
    fi
    
    # Extract prefix (everything before the first colon)
    prefix=$(echo "$commit" | grep -oE "^[a-zA-Z]+:" | tr -d ':' | tr '[:upper:]' '[:lower:]')
    
    # Remove prefix from message for cleaner output
    message=$(echo "$commit" | sed 's/^[a-zA-Z]*: *//')
    
    case "$prefix" in
        feat|feature)
            FEATURES="${FEATURES}- ${message}"$'\n'
            ;;
        fix|bugfix|bug)
            FIXES="${FIXES}- ${message}"$'\n'
            ;;
        refactor|perf|improve|enhancement)
            IMPROVEMENTS="${IMPROVEMENTS}- ${message}"$'\n'
            ;;
        chore|build|ci|style|docs|test)
            CHORES="${CHORES}- ${message}"$'\n'
            ;;
        *)
            # If no recognized prefix, include the full commit message
            OTHER="${OTHER}- ${commit}"$'\n'
            ;;
    esac
done <<< "$COMMITS"

# Build changelog entry
NEW_ENTRY="$HEADER"$'\n'

if [ -n "$FEATURES" ]; then
    NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Features"$'\n'"${FEATURES}"
fi

if [ -n "$FIXES" ]; then
    NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Bug Fixes"$'\n'"${FIXES}"
fi

if [ -n "$IMPROVEMENTS" ]; then
    NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Improvements"$'\n'"${IMPROVEMENTS}"
fi

if [ -n "$CHORES" ]; then
    NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Chores"$'\n'"${CHORES}"
fi

if [ -n "$OTHER" ]; then
    NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Other"$'\n'"${OTHER}"
fi

# Handle case where there are no commits
if [ -z "$FEATURES" ] && [ -z "$FIXES" ] && [ -z "$IMPROVEMENTS" ] && [ -z "$CHORES" ] && [ -z "$OTHER" ]; then
    NEW_ENTRY="${NEW_ENTRY}"$'\n'"- No significant changes."$'\n'
fi

NEW_ENTRY="${NEW_ENTRY}"$'\n'

# Prepend to CHANGELOG.md
if [ -f "$CHANGELOG_FILE" ]; then
    # Create a temp file
    echo "$NEW_ENTRY" | cat - "$CHANGELOG_FILE" > temp_changelog && mv temp_changelog "$CHANGELOG_FILE"
else
    echo "# Changelog" > "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
    echo "$NEW_ENTRY" >> "$CHANGELOG_FILE"
fi

echo -e "${GREEN}Changelog updated.${NC}"

# 4. Update State File
CURRENT_HEAD=$(git rev-parse HEAD)
echo "$CURRENT_HEAD" > "$STATE_FILE"
echo "Updated release state to $CURRENT_HEAD"

# 5. Commit changes automatically
COMMIT_MESSAGE="ci(release_sh): ${NEW_VERSION}-${NEW_BUILD}"
echo "Committing changes with message: $COMMIT_MESSAGE"

git add "$PROJECT_FILE" "$CHANGELOG_FILE" "$STATE_FILE"
git commit -m "$COMMIT_MESSAGE"

echo -e "${GREEN}Release $NEW_VERSION-$NEW_BUILD complete and committed!${NC}"
