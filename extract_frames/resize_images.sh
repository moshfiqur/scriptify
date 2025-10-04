#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") -i <input_dir> -o <output_dir> (-W <width> | -H <height>)

Resize all PNG images from input_dir, preserving aspect ratio, and write to output_dir.
Applies lossless PNG compression (strips metadata and uses maximum zlib compression).

Options:
  -i   Input directory containing PNG files
  -o   Output directory to write resized PNG files
  -W   Target width in pixels (height auto-calculated)
  -H   Target height in pixels (width auto-calculated)
  -h   Show this help message

Examples:
  $(basename "$0") -i frames -o resized -W 256
  $(basename "$0") -i frames -o resized -H 128
EOF
}

indir=""
outdir=""
width=""
height=""

while getopts ":i:o:W:H:h" opt; do
  case "$opt" in
    i) indir="$OPTARG" ;;
    o) outdir="$OPTARG" ;;
    W) width="$OPTARG" ;;
    H) height="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

# Validate arguments
[[ -n "$indir" ]] || { echo "Error: -i <input_dir> is required" >&2; usage; exit 2; }
[[ -n "$outdir" ]] || { echo "Error: -o <output_dir> is required" >&2; usage; exit 2; }

if { [[ -z "$width" ]] && [[ -z "$height" ]] ; } || { [[ -n "$width" ]] && [[ -n "$height" ]] ; }; then
  echo "Error: specify exactly one of -W <width> or -H <height>" >&2
  usage
  exit 2
fi

[[ -d "$indir" ]] || { echo "Error: input directory '$indir' does not exist or is not a directory" >&2; exit 2; }
mkdir -p "$outdir"

# Check ImageMagick 'magick' availability
if ! command -v magick >/dev/null 2>&1; then
  echo "Error: 'magick' command not found. Install ImageMagick (e.g., brew install imagemagick)." >&2
  exit 127
fi

# Build the resize geometry
geom=""
if [[ -n "$width" ]]; then
  if ! [[ "$width" =~ ^[0-9]+$ ]]; then
    echo "Error: width must be a positive integer" >&2
    exit 2
  fi
  geom="${width}x"   # width only, preserves aspect ratio
else
  if ! [[ "$height" =~ ^[0-9]+$ ]]; then
    echo "Error: height must be a positive integer" >&2
    exit 2
  fi
  geom="x${height}"  # height only, preserves aspect ratio
fi

# Iterate files safely (NUL-delimited) and resize
count=0
while IFS= read -r -d '' src; do
  base="$(basename "$src")"
  dst="$outdir/$base"
  magick "$src" \
    -resize "$geom" \
    -strip \
    -define png:compression-filter=5 \
    -define png:compression-level=9 \
    "$dst"
  ((count++))
done < <(find "$indir" -maxdepth 1 -type f \( -iname '*.png' \) -print0)

if (( count == 0 )); then
  echo "No PNG files found in '$indir'" >&2
  exit 2
fi

echo "Resized $count image(s) to: $(cd "$outdir" && pwd)"

