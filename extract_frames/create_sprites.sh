#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <png_directory>"
  echo "Creates sprite.png in the current directory by horizontally appending PNGs sorted by filename."
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

# Ensure ImageMagick is available
if command -v magick >/dev/null 2>&1; then
  IM="magick"
elif command -v convert >/dev/null 2>&1; then
  IM="convert"
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

# Compose horizontally (+append) into sprite.png in the current working directory.
"$IM" @"$tmp" +append "$out"

echo "Sprite written to: $(pwd)/$out"