#!/usr/bin/env bash

# Creates sprite.png in the current directory from PNGs sorted by filename.
# Usage: create_sprites_grid frames/256/
# Example: create_sprites_grid frames/1024/

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <png_directory>"
  echo "Creates sprite.png in the current directory from PNGs sorted by filename."
  echo "Behavior:"
  echo "  - <= 30 images: single-row (horizontal) sprite"
  echo "  - 31..149 images: grid with 10 rows and computed columns"
  echo "  - >= 150 images: grid with 15 rows and computed columns"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

indir="${1:-}"
if [[ -z "$indir" ]]; then
  echo "Error: missing <png_directory> argument." >&2
  usage
  exit 2
fi
if [[ ! -d "$indir" ]]; then
  echo "Error: '$indir' is not a directory." >&2
  exit 2
fi

# Ensure ImageMagick is available and detect montage capability for grids
IM=()
MONT=()
if command -v magick >/dev/null 2>&1; then
  IM=(magick)
  MONT=(magick montage)
elif command -v montage >/dev/null 2>&1; then
  MONT=(montage)
  if command -v convert >/dev/null 2>&1; then
    IM=(convert)
  fi
elif command -v convert >/dev/null 2>&1; then
  IM=(convert)
else
  echo "Error: ImageMagick not found. Install it, e.g. 'brew install imagemagick'." >&2
  exit 127
fi

out="sprite.png"

# Build a sorted list of PNG files (lexicographic by filename) and write to a temp list file.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

shopt -s nullglob
# Create list using NUL-safe pipeline, then sort filenames, and restore full paths.
# This avoids command-line length limits by using ImageMagick's @filelist syntax.
if ! printf '%s\0' "$indir"/*.png \
  | xargs -0 -n1 basename \
  | LC_ALL=C sort \
  | sed "s|^|$indir/|" > "$tmp"; then
  echo "Error: failed building file list." >&2
  exit 1
fi
if [[ ! -s "$tmp" ]]; then
  echo "Error: no PNG files found in '$indir'." >&2
  exit 2
fi

# Count images (portable; avoid Bash 4+ mapfile)
count=$(wc -l < "$tmp" | tr -d ' ')

if (( count <= 30 )); then
  # Single-row sprite using +append
  if [[ ${#IM[@]} -eq 0 ]]; then
    echo "Error: cannot create sprite; 'convert' or 'magick' is required." >&2
    exit 127
  fi
  "${IM[@]}" @"$tmp" +append "$out"
  echo "Single-row sprite (count=$count) written to: $(pwd)/$out"
else
  # Grid sprite requires montage (or magick montage)
  if [[ ${#MONT[@]} -eq 0 ]]; then
    echo "Error: grid sprite requires 'montage' (install ImageMagick)." >&2
    exit 127
  fi

  if (( count < 150 )); then
    rows=10
  else
    rows=15
  fi
  # columns = ceil(count / rows)
  cols=$(( (count + rows - 1) / rows ))

  "${MONT[@]}" @"$tmp" -mode concatenate -tile "${cols}x${rows}" -geometry +0+0 "$out"
  echo "Grid sprite (${rows} rows x ${cols} cols, count=$count) written to: $(pwd)/$out"
fi