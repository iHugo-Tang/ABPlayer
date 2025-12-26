#!/bin/bash

# Configuration
REPO="sunset-valley/ABPlayer"
APP_NAME="ABPlayer"
INSTALL_DIR="/Applications"
TEMP_DIR="/tmp/abplayer_update"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# 0. Preparation
mkdir -p "$TEMP_DIR"

# 1. Get Download URL
VERSION="latest"
if [ "$1" ]; then
    VERSION="$1"
fi

log_info "Fetching download URL for version: $VERSION"

if [ "$VERSION" == "latest" ]; then
    # Get the latest release metadata
    LATEST_RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"
    RESPONSE=$(curl -s "$LATEST_RELEASE_URL")
    
    # Extract tag name (version)
    RESOLVED_VERSION=$(echo "$RESPONSE" | grep '"tag_name":' | head -n 1 | cut -d '"' -f 4)
    
    if [ -z "$RESOLVED_VERSION" ]; then
        log_error "Could not resolve latest version. API response might be rate limited or invalid."
        exit 1
    fi

    log_info "Resolved latest version: $RESOLVED_VERSION"
    VERSION="$RESOLVED_VERSION"
    
    # Extract download URL
    DOWNLOAD_URL=$(echo "$RESPONSE" | grep "browser_download_url.*zip" | cut -d '"' -f 4)
else
    # Construct URL for specific version
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/$APP_NAME.zip"
fi

if [ -z "$DOWNLOAD_URL" ]; then
    log_error "Could not find download URL for version $VERSION"
    exit 1
fi

log_info "Download URL: $DOWNLOAD_URL"

# 2. Download
ZIP_FILE="$TEMP_DIR/$APP_NAME.zip"
log_info "Downloading..."
curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL" --fail

if [ $? -ne 0 ]; then
    log_error "Download failed."
    exit 1
fi

# 3. Unzip
log_info "Unzipping..."
unzip -o -q "$ZIP_FILE" -d "$TEMP_DIR"

if [ ! -d "$TEMP_DIR/$APP_NAME.app" ]; then
    log_error "App not found in zip file."
    exit 1
fi

# 4. Install
log_info "Installing to $INSTALL_DIR..."

# Remove existing app if it exists
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

# Move new app
mv "$TEMP_DIR/$APP_NAME.app" "$INSTALL_DIR/"

# 5. Remove Quarantine
log_info "Removing quarantine attributes..."
sudo xattr -rd com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app"

log_info "Update complete! You can now run $APP_NAME."
