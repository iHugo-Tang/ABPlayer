#!/usr/bin/env bash
set -e

BID="cc.ihugo.app.ABPlayer"

echo "Killing app (best effort)..."
pkill -f "$BID" 2>/dev/null || true

echo "Removing containers..."
rm -rf "$HOME/Library/Containers/$BID"
rm -rf "$HOME/Library/Group Containers/"*"$BID"* 2>/dev/null || true

echo "Removing support/cache/prefs/state..."
rm -rf "$HOME/Library/Application Support/$BID"
rm -rf "$HOME/Library/Caches/$BID"
rm -f  "$HOME/Library/Preferences/$BID.plist"
rm -rf "$HOME/Library/Saved Application State/$BID.savedState"
rm -rf "$HOME/Library/Logs/$BID"

echo "Done. Launch app again to simulate first run."