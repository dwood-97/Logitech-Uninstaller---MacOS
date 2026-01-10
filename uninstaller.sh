#!/usr/bin/env bash
# Logitech G HUB deep uninstall (macOS)
# - Uses Logitech's own lghub_updater --uninstall when available
# - Removes common leftovers (user + shared + launchd)
# - Includes dry-run, logging, and guardrails
#
# Usage:
#   ./uninstaller.sh
#   ./uninstaller.sh --dry-run
#   ./uninstaller.sh --no-backup
#
set -euo pipefail

DRY_RUN=0
DO_BACKUP=1
LOG_FILE="${TMPDIR:-/tmp}/ghub_uninstall_$(date +%Y%m%d_%H%M%S).log"

for arg in "${@:-}"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-backup) DO_BACKUP=0 ;;
    -h|--help)
      cat <<EOF
Logitech G HUB deep uninstall (macOS)

Options:
  --dry-run     Print actions without deleting anything
  --no-backup   Skip backups of user config folders
  -h, --help    Show this help
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

log() {
  # shellcheck disable=SC2059
  printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}
warn() { log "WARN: $*"; }
die() { log "ERROR: $*"; exit 1; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] $*"
    return 0
  fi
  log "RUN: $*"
  # shellcheck disable=SC2048
  eval "$@" >>"$LOG_FILE" 2>&1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

need_cmd id
need_cmd launchctl
need_cmd rm
need_cmd mkdir
need_cmd cp
need_cmd ps

log "Log file: $LOG_FILE"
log "Dry run: $DRY_RUN | Backup: $DO_BACKUP"

# Ask for sudo once up front (and keep it alive)
if [[ "$DRY_RUN" -eq 0 ]]; then
  sudo -v || die "Sudo auth failed."
  # Keep sudo alive until script exits
  ( while true; do sudo -n true; sleep 30; done ) >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true' EXIT
else
  log "[dry-run] Skipping sudo auth."
fi

USER_ID="$(id -u)"
USER_NAME="$(id -un)"
HOME_DIR="${HOME}"

log "User: $USER_NAME (uid=$USER_ID) | Home: $HOME_DIR"

# --- Helper: safe delete with checks ---
safe_rm() {
  local target="$1"
  if [[ -z "$target" ]]; then
    warn "safe_rm called with empty path; skipping"
    return 0
  fi
  if [[ "$target" == "/" || "$target" == "$HOME_DIR" ]]; then
    warn "Refusing to delete dangerous path: $target"
    return 0
  fi
  if [[ -e "$target" ]]; then
    run "rm -rf \"${target}\""
  else
    log "SKIP (not found): $target"
  fi
}

# --- Identify install locations ---
APP_CANDIDATES=(
  "/Applications/lghub.app"
  "/System/Volumes/Data/Applications/lghub.app"
  "/Applications/Logitech G HUB.app"
  "/System/Volumes/Data/Applications/Logitech G HUB.app"
)

FOUND_APP=""
for p in "${APP_CANDIDATES[@]}"; do
  if [[ -d "$p" ]]; then
    FOUND_APP="$p"
    break
  fi
done

if [[ -n "$FOUND_APP" ]]; then
  log "Found G HUB app: $FOUND_APP"
else
  warn "G HUB app not found in common locations. Will still attempt cleanup."
fi

# --- Find lghub_updater binary (multiple known layouts) ---
UPDATER_CANDIDATES=(
  # Common reddit path (frameworks)
  "/Applications/lghub.app/Contents/Frameworks/lghub_updater.app/Contents/MacOS/lghub_updater"
  "/System/Volumes/Data/Applications/lghub.app/Contents/Frameworks/lghub_updater.app/Contents/MacOS/lghub_updater"

  # Alternate layout seen in the wild
  "/Applications/lghub.app/Contents/MacOS/lghub_updater.app/Contents/MacOS/lghub_updater"
  "/System/Volumes/Data/Applications/lghub.app/Contents/MacOS/lghub_updater.app/Contents/MacOS/lghub_updater"
)

FOUND_UPDATER=""
for u in "${UPDATER_CANDIDATES[@]}"; do
  if [[ -x "$u" ]]; then
    FOUND_UPDATER="$u"
    break
  fi
done

# If still not found, try locating within discovered app bundle
if [[ -z "$FOUND_UPDATER" && -n "$FOUND_APP" ]]; then
  log "Updater not found in known paths; scanning app bundle for lghub_updater..."
  # Scan without exploding on spaces
  while IFS= read -r candidate; do
    if [[ -x "$candidate" ]]; then
      FOUND_UPDATER="$candidate"
      break
    fi
  done < <(find "$FOUND_APP" -type f -name "lghub_updater" 2>/dev/null || true)
fi

if [[ -n "$FOUND_UPDATER" ]]; then
  log "Found lghub_updater: $FOUND_UPDATER"
else
  warn "Could not find lghub_updater. Will proceed with manual cleanup."
fi

# --- Cleanly unload launchd items (avoid pkill -f which can blank screens) ---
# Known/likely launchd plists (user + system)
LAUNCHD_SYSTEM_PLISTS=(
  "/Library/LaunchDaemons/com.logitech.manager.daemon.plist"
  "/Library/LaunchDaemons/com.logitech.ghub.updater.plist"
  "/Library/LaunchDaemons/com.logitech.ghub.plist"
)

LAUNCHD_USER_PLISTS=(
  "$HOME_DIR/Library/LaunchAgents/com.logitech.ghub.plist"
  "$HOME_DIR/Library/LaunchAgents/com.logitech.ghub.agent.plist"
  "$HOME_DIR/Library/LaunchAgents/com.logitech.manager.helper.plist"
)

log "Unloading launchd items (if present)..."
for plist in "${LAUNCHD_SYSTEM_PLISTS[@]}"; do
  if [[ -f "$plist" ]]; then
    run "sudo launchctl bootout system \"$plist\" || true"
  else
    log "SKIP (not found): $plist"
  fi
done

for plist in "${LAUNCHD_USER_PLISTS[@]}"; do
  if [[ -f "$plist" ]]; then
    run "launchctl bootout gui/$USER_ID \"$plist\" || true"
  else
    log "SKIP (not found): $plist"
  fi
done

# --- Run Logitech's official uninstall if possible ---
if [[ -n "$FOUND_UPDATER" ]]; then
  log "Running Logitech uninstaller..."
  run "sudo \"$FOUND_UPDATER\" --uninstall || true"
else
  warn "Skipping official uninstall step (updater binary not found)."
fi

# --- Optional backup of user config ---
BACKUP_DIR="$HOME_DIR/Desktop/GHUB_Backup_$(date +%Y%m%d_%H%M%S)"
if [[ "$DO_BACKUP" -eq 1 ]]; then
  log "Backing up user config (if present) to: $BACKUP_DIR"
  run "mkdir -p \"$BACKUP_DIR\""
  for b in \
    "$HOME_DIR/Library/Application Support/lghub" \
    "$HOME_DIR/Library/Application Support/G HUB" \
    "$HOME_DIR/Library/Preferences/com.logitech.ghub.plist" \
    "$HOME_DIR/Library/Preferences/com.logitech.lghub.plist" \
    ; do
    if [[ -e "$b" ]]; then
      run "cp -a \"$b\" \"$BACKUP_DIR/\" || true"
    else
      log "SKIP (not found): $b"
    fi
  done
else
  log "Backup disabled (--no-backup)."
fi

# --- Remove app bundle(s) ---
log "Removing app bundle(s)..."
safe_rm "/Applications/lghub.app"
safe_rm "/System/Volumes/Data/Applications/lghub.app"
safe_rm "/Applications/Logitech G HUB.app"
safe_rm "/System/Volumes/Data/Applications/Logitech G HUB.app"

# --- Remove common leftovers ---
log "Removing common leftovers..."

# User-level
safe_rm "$HOME_DIR/Library/Application Support/lghub"
safe_rm "$HOME_DIR/Library/Application Support/G HUB"
safe_rm "$HOME_DIR/Library/Caches/com.logitech.ghub"
safe_rm "$HOME_DIR/Library/Caches/lghub"
safe_rm "$HOME_DIR/Library/Preferences/com.logitech.ghub.plist"
safe_rm "$HOME_DIR/Library/Preferences/com.logitech.lghub.plist"
safe_rm "$HOME_DIR/Library/Saved Application State/com.logitech.ghub.savedState"
safe_rm "$HOME_DIR/Library/HTTPStorages/com.logitech.ghub"
safe_rm "$HOME_DIR/Library/Logs/lghub"
safe_rm "$HOME_DIR/Library/Logs/Logitech"
safe_rm "$HOME_DIR/Library/Preferences/ByHost/com.logitech.ghub.*.plist"

# Shared folders from original script + common variants
safe_rm "/Users/Shared/LGHUB"
safe_rm "/Users/Shared/LGHUB/"
safe_rm "/Users/Shared/.logishrd"
safe_rm "/Users/Shared/.logi"

# System-level support files that are commonly GHUB-related (keep narrow)
safe_rm "/Library/Application Support/Logitech/GHUB"
safe_rm "/Library/Application Support/lghub"
safe_rm "/Library/Logs/Logitech"
safe_rm "/Library/Preferences/com.logitech.ghub.plist"

# Remove launchd plist files themselves (after bootout)
for plist in "${LAUNCHD_SYSTEM_PLISTS[@]}"; do safe_rm "$plist"; done
for plist in "${LAUNCHD_USER_PLISTS[@]}"; do safe_rm "$plist"; done

# --- Final: show any remaining Logitech/GHUB processes ---
log "Checking for remaining Logitech/GHUB processes..."
if ps aux | grep -Ei 'lghub|ghub|logitech' | grep -v grep >/dev/null 2>&1; then
  warn "Some Logitech/GHUB-related processes still appear to be running:"
  ps aux | grep -Ei 'lghub|ghub|logitech' | grep -v grep | tee -a "$LOG_FILE"
  warn "A reboot is recommended."
else
  log "No obvious Logitech/GHUB processes detected."
fi

log "Done. If you had issues before, reboot now."
log "If you need to share debug info on Reddit, paste: $LOG_FILE"
