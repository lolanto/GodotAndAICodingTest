#!/usr/bin/env bash
# run.sh — GravityRush quick launch script
# Platform: macOS only (uses Engine/Godot.app)
# Usage:
#   ./run.sh           Run the game (no editor)
#   ./run.sh --editor  Open the Godot editor

GODOT="Engine/Godot.app/Contents/MacOS/Godot"
PROJECT="Game"

if [ "$1" = "--editor" ]; then
    "$GODOT" -e --path "$PROJECT"
else
    "$GODOT" --path "$PROJECT"
fi
