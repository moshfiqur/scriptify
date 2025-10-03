#!/bin/bash
# Fancy per-item rsync (SOURCE → DESTINATION)

set -euo pipefail

# ====== CONFIG ======
SOURCE="/Users/sparrow/srv/Movie_Making/"          
DESTINATION="/Volumes/Elementary/srv/Movie_Making/"
LOG_DIR="$HOME/.local/var/rsync-logs"
RSYNC_OPTS=(
  -avh --progress
  # Exclusions
  --exclude '.DS_Store'
  --exclude 'node_modules/'
  --exclude 'venv/'
  --exclude '.venv/'
  --exclude 'env/'
  --exclude '.env/'
  --exclude '__pycache__/'
)
# ====================

mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/rsync_$(date +%Y-%m-%d_%H-%M-%S).log"

# Colors only if TTY
if [[ -t 1 ]]; then
  BOLD="$(tput bold)"; DIM="$(tput dim)"; RESET="$(tput sgr0)"
  GREEN="$(tput setaf 2)"; CYAN="$(tput setaf 6)"; YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; CYAN=""; YELLOW=""; RED=""
fi

log()    { printf "%s[%s]%s %s\n" "$DIM" "$(date '+%F %T')" "$RESET" "$*" | tee -a "$LOGFILE"; }
ok()     { printf "%s✔%s %s\n" "$GREEN" "$RESET" "$*" | tee -a "$LOGFILE"; }
info()   { printf "%sℹ%s %s\n" "$CYAN" "$RESET" "$*" | tee -a "$LOGFILE"; }
warn()   { printf "%s⚠%s %s\n" "$YELLOW" "$RESET" "$*" | tee -a "$LOGFILE"; }
fail()   { printf "%s✖%s %s\n" "$RED" "$RESET" "$*" | tee -a "$LOGFILE"; }

trap 'fail "An error occurred. See log: $LOGFILE"; exit 1' ERR

[[ "$SOURCE" == */ ]] || { fail "SOURCE must end with /"; exit 2; }
[[ "$DESTINATION" == */ ]] || { fail "DESTINATION must end with /"; exit 2; }

log  "${BOLD}Starting per-item sync${RESET}"
info "Source:      $SOURCE"
info "Destination: $DESTINATION"
info "Log file:    $LOGFILE"

shopt -s dotglob nullglob
items=( "${SOURCE}"* )

if (( ${#items[@]} == 0 )); then
  warn "No items found in source. Nothing to sync."
  exit 0
fi

for item in "${items[@]}"; do
  rel="${item#"$SOURCE"}"

  # Skip excluded top-level items to avoid rsync errors on single excluded files
  # 1) Skip .DS_Store if it's a file
  if [[ "$rel" == ".DS_Store" && -f "$item" ]]; then
    info "Skipping excluded item: $rel"
    continue
  fi
  # 2) Skip virtualenv and node_modules if they are directories
  if [[ -d "$item" ]]; then
    case "$rel" in
      node_modules|venv|.venv|env|.env)
        info "Skipping excluded directory: $rel"
        continue
        ;;
    esac
  fi

  if [[ -d "$item" ]]; then
    log  "${BOLD}📁 Copying contents of folder:${RESET} $rel"
    mkdir -p "${DESTINATION}${rel}"
    # Run rsync in a pipeline but capture its exit status
    set +e
    rsync "${RSYNC_OPTS[@]}" "$item"/ "${DESTINATION}${rel}"/ | tee -a "$LOGFILE" || true
    rs_status=${PIPESTATUS[0]}
    set -e
    if [[ $rs_status -eq 0 || $rs_status -eq 24 ]]; then
      ok   "Done folder: $rel"
    else
      fail "rsync failed for folder: $rel (exit $rs_status)"
      exit "$rs_status"
    fi
  elif [[ -f "$item" ]]; then
    log  "${BOLD}📄 Copying file:${RESET} $rel"
    mkdir -p "$(dirname "${DESTINATION}${rel}")"
    # Run rsync in a pipeline but capture its exit status
    set +e
    rsync "${RSYNC_OPTS[@]}" "$item" "${DESTINATION}${rel}" | tee -a "$LOGFILE" || true
    rs_status=${PIPESTATUS[0]}
    set -e
    if [[ $rs_status -eq 0 || $rs_status -eq 24 ]]; then
      ok   "Done file: $rel"
    else
      fail "rsync failed for file: $rel (exit $rs_status)"
      exit "$rs_status"
    fi
  else
    warn "Skipping non-regular item: $rel"
  fi
done

ok "${BOLD}All items synced successfully.${RESET}"
