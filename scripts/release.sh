#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# GitHub repository info
REPO_OWNER="sunset-valley"
REPO_NAME="ABPlayer"

# Function to increment patch version
increment_version() {
    local version=$1
    # Remove 'v' prefix if present
    version=${version#v}
    
    # Split version into parts
    IFS='.' read -ra parts <<< "$version"
    local major=${parts[0]:-0}
    local minor=${parts[1]:-0}
    local patch=${parts[2]:-0}
    
    # Increment patch version
    patch=$((patch + 1))
    
    echo "$major.$minor.$patch"
}

# Check if version argument is provided
if [ -z "$1" ]; then
    echo "No version specified. Fetching latest version from GitHub releases..."
    
    # Get latest release version from GitHub API
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${RED}Error: Could not fetch latest version from GitHub. Please provide a version manually.${NC}"
        exit 1
    fi
    
    echo "Latest version: $LATEST_VERSION"
    NEW_VERSION=$(increment_version "$LATEST_VERSION")
    echo "New version: $NEW_VERSION"
else
    NEW_VERSION="$1"
fi
PROJECT_FILE="Project.swift"
CHANGELOG_FILE="CHANGELOG.md"
STATE_FILE=".release_state"

# 1. Update Project.swift
echo "Updating version to $NEW_VERSION in $PROJECT_FILE..."
if [ -f "$PROJECT_FILE" ]; then
    # Update CFBundleShortVersionString
    sed -i '' "s/\"CFBundleShortVersionString\": \".*\"/\"CFBundleShortVersionString\": \"$NEW_VERSION\"/" "$PROJECT_FILE"
else
    echo -e "${RED}Error: $PROJECT_FILE not found!${NC}"
    exit 1
fi

# 2. Generate Changelog
echo "Generating changelog..."

DATE=$(date +%Y-%m-%d)
HEADER="## [$NEW_VERSION] - $DATE"

# Determine commit range
if [ -f "$STATE_FILE" ]; then
    LAST_COMMIT=$(cat "$STATE_FILE")
    echo "Found last release commit: $LAST_COMMIT"
    # Check if the commit actually exists
    if git cat-file -e "$LAST_COMMIT" 2>/dev/null; then
        COMMITS=$(git log --pretty=format:"%s" "$LAST_COMMIT..HEAD")
    else
        echo -e "${RED}Warning: Last commit $LAST_COMMIT not found. Defaulting to last 10 commits.${NC}"
        COMMITS=$(git log -n 10 --pretty=format:"%s")
    fi
else
    echo "No previous release state found. Defaulting to last 10 commits."
    COMMITS=$(git log -n 10 --pretty=format:"%s")
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

# 3. Update State File
CURRENT_HEAD=$(git rev-parse HEAD)
echo "$CURRENT_HEAD" > "$STATE_FILE"
echo "Updated release state to $CURRENT_HEAD"

echo -e "${GREEN}Release $NEW_VERSION preparation complete!${NC}"
echo "Please review changes and commit."
