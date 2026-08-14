#!/usr/bin/env bash

# ---------------------------------------------------------
# Godot 4 + Butler Automated Build & Deploy Pipeline
# Run this from the root directory of your Godot project.
# ---------------------------------------------------------

# --- Configuration (Edit these for your jam) ---
GODOT_EXEC="godot" # Or the full path to your Godot executable
BUTLER_EXEC="butler"
ITCH_USER="budtard"
ITCH_GAME="godot-wild-96name-tbd"

# Godot Export settings
EXPORT_PRESET="Web" # Must match the name exactly in export_presets.cfg
BUILD_DIR="build/web"
BUILD_TARGET="$BUILD_DIR/index.html"
ITCH_CHANNEL="web" # The itch.io channel (web, windows, linux)

echo "🚀 Starting automated build pipeline..."

# --- 1. Clean previous build ---
echo "🧹 Cleaning old build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- 2. Headless Godot Export ---
echo "⚙️ Exporting Godot project (Preset: $EXPORT_PRESET)..."
# The --headless flag builds the game without launching the editor UI
$GODOT_EXEC --headless --export-release "$EXPORT_PRESET" "$BUILD_TARGET"

if [ $? -ne 0 ]; then
    echo "❌ Godot export failed! Check your export_presets.cfg. Aborting."
    exit 1
fi
echo "✅ Godot export successful!"

# --- 3. Push to itch.io via Butler ---
echo "🛸 Pushing build to itch.io ($ITCH_USER/$ITCH_GAME:$ITCH_CHANNEL)..."
$BUTLER_EXEC push "$BUILD_DIR" "$ITCH_USER/$ITCH_GAME:$ITCH_CHANNEL"

if [ $? -ne 0 ]; then
    echo "❌ Butler push failed!"
    exit 1
fi

echo "🎉 Build successfully deployed to itch.io!"
