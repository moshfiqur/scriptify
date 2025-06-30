#!/bin/bash

# ==============================================================================
# Project Cleaner Script
#
# Description:
# This script recursively traverses a specified directory and deletes folders
# that typically contain dependencies, version control data, or build artifacts.
#
# It targets and deletes:
#   1. `node_modules` - Common in Node.js/JavaScript projects.
#   2. `.git` - The hidden directory for Git version control repositories.
#   3. `build` - A common output directory for Flutter, C++, and other projects.
#
# Usage:
#   ./clean.sh /path/to/your/projects_folder
#   ./clean.sh /path/to/your/projects_folder --dry-run
#
# Options:
#   --dry-run   Run the script without deleting any files. It will only print
#               the paths of the folders that would be deleted.
#
# Safety:
#   - The script will ask for confirmation before deleting anything unless
#     --dry-run is specified.
#   - It uses 'set -e' to exit immediately if any command fails.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Function to display usage information ---
usage() {
    echo "Usage: $0 <path_to_directory> [--dry-run]"
    echo "Example: $0 ~/dev/my-projects"
    echo "Example (Dry Run): $0 ~/dev/my-projects --dry-run"
    echo ""
    echo "This script recursively cleans a directory by deleting:"
    echo "  - All 'node_modules' folders"
    echo "  - All '.git' folders"
    echo "  - All 'build' folders"
    exit 1
}

# --- Function to process directories for cleanup ---
# Arguments:
#   $1: The name of the directory to find (e.g., "node_modules")
#   $2: The root directory to search within
#   $3: Boolean indicating if it's a dry run (true/false)
process_folders() {
    local folder_name="$1"
    local search_dir="$2"
    local is_dry_run="$3"
    
    echo "🔎 Searching for '$folder_name' folders..."
    
    # The 'find' command locates the directories.
    # -type d:  Ensures we only match directories.
    # -prune:   Stops 'find' from descending into a matched directory.
    local found_items
    found_items=$(find "$search_dir" -name "$folder_name" -type d -prune)

    if [ -n "$found_items" ]; then
        if [ "$is_dry_run" = true ]; then
            # In dry-run mode, just print what would be deleted.
            echo "$found_items" | while IFS= read -r line; do
                echo "  DRY RUN: Would delete '$line'"
            done
        else
            # In normal mode, print and then delete.
            echo "$found_items" | while IFS= read -r line; do
                echo "  🔥 Deleting '$line'"
            done
            echo "$found_items" | xargs rm -rf
        fi
    else
        echo "  ✅ No '$folder_name' folders found."
    fi
    echo "" # Add a newline for better readability
}


# --- Main Script Logic ---

# 1. Initialize and Parse Arguments
# ------------------------------------------------------------------------------
DRY_RUN=false
TARGET_DIR=""

if [ "$#" -eq 0 ]; then
    echo "Error: No directory path was provided."
    usage
fi

for arg in "$@"; do
    case $arg in
        --dry-run)
        DRY_RUN=true
        ;;
        *)
        # Assume any argument that isn't a flag is the target directory.
        if [[ ! "$arg" =~ ^- ]]; then
            TARGET_DIR="$arg"
        fi
        ;;
    esac
done

# 2. Validate Input
# ------------------------------------------------------------------------------
if [ -z "$TARGET_DIR" ]; then
    echo "Error: No directory path was specified."
    usage
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: The path '$TARGET_DIR' is not a valid directory."
    exit 1
fi

# 3. User Confirmation & Execution
# ------------------------------------------------------------------------------
# Resolve the full, absolute path for clarity.
FULL_PATH=$(realpath "$TARGET_DIR")

if [ "$DRY_RUN" = true ]; then
    echo "--- Starting Dry Run Mode (no files will be deleted) ---"
    echo "Target directory: $FULL_PATH"
    echo "--------------------------------------------------------"
else
    echo "⚠️  This script will permanently delete items from: $FULL_PATH"
    echo "It will search for and remove all sub-folders with the following names:"
    echo "  - node_modules"
    echo "  - .git"
    echo "  - build"
    echo ""

    # Prompt the user for confirmation before proceeding.
    read -p "Are you absolutely sure you want to continue? [y/N] " -n 1 -r
    echo # Move to a new line after the user's input.

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled by user."
        exit 0
    fi
    echo "-----------------------------------"
    echo "Proceeding with cleanup..."
    echo "-----------------------------------"
fi

# Call the processing function for each directory type
process_folders "node_modules" "$TARGET_DIR" "$DRY_RUN"
process_folders ".git" "$TARGET_DIR" "$DRY_RUN"
process_folders "build" "$TARGET_DIR" "$DRY_RUN"

# 4. Completion
# ------------------------------------------------------------------------------
echo "-----------------------------------"
if [ "$DRY_RUN" = true ]; then
    echo "✅ Dry run complete. No files were changed."
else
    echo "🎉 Cleanup complete!"
fi
echo "-----------------------------------"

