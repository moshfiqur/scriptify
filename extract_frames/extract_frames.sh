#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") -i <input.mp4> [-f fps=24] [-o outdir=frames] [-y]"
  echo "  -y  overwrite existing files without prompt"
}

input=""
fps=24
outdir="frames"
overwrite="no"

while getopts ":i:f:o:yh" opt; do
  case "$opt" in
    i) input="$OPTARG" ;;
    f) fps="$OPTARG" ;;
    o) outdir="$OPTARG" ;;
    y) overwrite="yes" ;;
    h) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

[[ -n "$input" ]] || { usage; exit 2; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found. brew install ffmpeg" >&2; exit 127; }

mkdir -p "$outdir"

args=(-hide_banner -loglevel error -nostdin)
[[ "$overwrite" == "yes" ]] && args+=(-y) || args+=(-n)
args+=(-i "$input" -vf "fps=${fps}" -start_number 1 "$outdir/frame_%05d.png")

ffmpeg "${args[@]}"

echo "Frames written to: $(cd "$outdir" && pwd)"
