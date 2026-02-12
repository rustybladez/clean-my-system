#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# Config
# -------------------------
TARGET_DIR="${HOME}"
DUPLICATE_DIR="${HOME}/Documents"
LOG_DAYS=7
DRY_RUN=true   # set to false to actually delete/rename

# Use mktemp for safe temporary files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# -------------------------
# Helpers
# -------------------------
run() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY] $*"
  else
    # Use "$@" instead of eval to avoid injection
    "$@"
  fi
}

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# -------------------------
# 1. System cleanup
# -------------------------
clean_system() {
  log "== System cleanup =="
  
  # Only clean user-owned cache directories
  if [ -d "$HOME/.cache" ]; then
    run rm -rf "${HOME:?}/.cache/"*
  fi
  
  # Firefox cache (if exists)
  for profile in "$HOME"/.mozilla/firefox/*/cache2; do
    [ -d "$profile" ] && run rm -rf "${profile:?}/"*
  done
  
  # Chrome cache (if exists)
  local chrome_cache="$HOME/.config/google-chrome/Default/Cache"
  if [ -d "$chrome_cache" ]; then
    run rm -rf "${chrome_cache:?}/"*
  fi
  
  # Don't touch /tmp or /var/log without root - they're system directories
  # User should run with sudo if they want system-wide cleanup
  if [ "$EUID" -eq 0 ]; then
    log "Running as root - cleaning system logs"
    run find /var/log -type f -mtime +"$LOG_DAYS" -name "*.log" -delete
    # Don't delete all of /tmp/* - too dangerous
  else
    log "Skipping system-wide cleanup (requires root)"
  fi
}

# -------------------------
# 2. Find duplicates
# -------------------------
find_duplicates() {
  log "== Finding duplicates in $DUPLICATE_DIR =="
  
  if [ ! -d "$DUPLICATE_DIR" ]; then
    log "ERROR: Directory $DUPLICATE_DIR does not exist"
    return 1
  fi
  
  local sizes_file="${TEMP_DIR}/sizes.txt"
  local hashes_file="${TEMP_DIR}/hashes.txt"
  local duplicates_file="${TEMP_DIR}/duplicates.txt"
  
  # Find files, get sizes
  find "$DUPLICATE_DIR" -type f -size +1M -print0 2>/dev/null | \
    xargs -0 stat -f "%z %N" 2>/dev/null | \
    sort -n > "$sizes_file" || {
      # Fallback for GNU stat
      find "$DUPLICATE_DIR" -type f -size +1M -print0 2>/dev/null | \
        xargs -0 stat -c "%s %n" 2>/dev/null | \
        sort -n > "$sizes_file"
    }
  
  if [ ! -s "$sizes_file" ]; then
    log "No files larger than 1MB found"
    return 0
  fi
  
  # Calculate hashes only for files with duplicate sizes
  awk '{print $1}' "$sizes_file" | sort | uniq -d > "${TEMP_DIR}/dup_sizes.txt"
  
  while IFS= read -r size; do
    grep "^${size} " "$sizes_file" | while IFS= read -r line; do
      file="${line#* }"
      if [ -f "$file" ]; then
        sha256sum "$file" 2>/dev/null || true
      fi
    done
  done < "${TEMP_DIR}/dup_sizes.txt" > "$hashes_file"
  
  # Find actual duplicates
  awk '{print $1}' "$hashes_file" | sort | uniq -d | while IFS= read -r hash; do
    grep "^${hash} " "$hashes_file"
  done > "$duplicates_file"
  
  if [ -s "$duplicates_file" ]; then
    log "Duplicate files found:"
    cat "$duplicates_file"
    log "Total duplicate groups: $(awk '{print $1}' "$duplicates_file" | uniq | wc -l)"
  else
    log "No duplicates found"
  fi
}

# -------------------------
# 3. Bulk renaming
# -------------------------
bulk_rename() {
  log "== Bulk renaming in $TARGET_DIR =="
  
  if [ ! -d "$TARGET_DIR" ]; then
    log "ERROR: Directory $TARGET_DIR does not exist"
    return 1
  fi
  
  local rename_count=0
  local collision_count=0
  
  # Save current directory
  local original_dir
  original_dir=$(pwd)
  
  cd "$TARGET_DIR" || return 1
  
  # Use find instead of glob to handle special characters
  find . -maxdepth 1 -type f -print0 | while IFS= read -r -d '' f; do
    # Remove leading ./
    f="${f#./}"
    
    # Skip if already processing
    [ -z "$f" ] && continue
    
    new=$(echo "$f" \
      | tr '[:upper:]' '[:lower:]' \
      | tr ' ' '-' \
      | sed 's/[^a-z0-9._-]//g')
    
    if [ "$f" != "$new" ] && [ -n "$new" ]; then
      # Check for collision
      if [ -e "$new" ] && [ "$f" != "$new" ]; then
        log "WARNING: Collision detected - $new already exists, skipping $f"
        ((collision_count++))
      else
        run mv -n "$f" "$new"
        ((rename_count++))
      fi
    fi
  done
  
  cd "$original_dir" || return 1
  
  log "Renamed $rename_count files, $collision_count collisions avoided"
}

# -------------------------
# Main
# -------------------------
main() {
  log "Starting cleanup script (DRY_RUN=$DRY_RUN)"
  
  clean_system
  find_duplicates
  bulk_rename
  
  log "Done."
}

main "$@"