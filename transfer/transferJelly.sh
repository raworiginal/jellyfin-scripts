#!/bin/bash
set -euo pipefail

# === CONFIG ===
export LOG_TAG="transferJelly"
export LOG_VERBOSE=true

# === IMPORT HELPERS ===
source $HOME/Documents/GitHub/scripts/lib/log.sh
source $HOME/Documents/GitHub/scripts/lib/suspend-guard.sh
source $HOME/Documents/GitHub/scripts/lib/email.sh

trap restore_suspend_setting EXIT INT TERM
compose_summary() {
  # Get the line number of the last "Starting transfer..." log entry
  START_LINE="$(journalctl -t "$LOG_TAG" | grep -n "Starting transfer..." | tail -n 1 | cut -d: -f1)"

  # If no such line is found, log a warning and skip the summary
  if [[ -z "$START_LINE" ]]; then
    log "WARN" "No 'Starting transfer...' entry found in journal. Skipping summary email."
    return
  fi

  # Get logs from that point to the end
  LOG_BODY="$(journalctl -t "$LOG_TAG" | tail -n +"$START_LINE")"

  # Construct a timestamped subject line
  EMAIL_SUBJECT="$(date +'%F_%H-%M-%S') - $(hostname) - $LOG_TAG summary"

  # Send the email using your helper function
  send_summary_email "$EMAIL_SUBJECT" "$LOG_BODY" "$EMAIL_RECIPIENT"
}

trap compose_summary EXIT

# === DRY RUN ===
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  log "INFO" "Dry run mode enabled. No files will be moved or deleted."
fi

# === ENV FILE LOADING ===
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  source "$SCRIPT_DIR/.env"
else
  log "ERR" ".env file not found. Exiting."
  exit 1
fi 

# === ENV VALIDATION ===
if [ -z "${SOURCE_DIR:-}" ] || [ -z "${DESTINATION:-}" ] || [ -z "${JELLY_API_URL:-}" ]; then
  log "ERR" "One or more required environment variables are not set. Exiting."
  exit 1
fi

# === RSYNC SETUP ===
RSYNC_OPTS="-avh --info=progress2 --partial --stats --remove-source-files"
if [[ "$DRY_RUN" == true ]]; then
  RSYNC_OPTS+=" --dry-run"
fi

# === RETRY LOGIC ===
MAX_RETRIES=3
RETRY_COUNT=0
log "INFO" "Starting transfer..."
while [[ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]]; do
  log "INFO" "Attempt $((RETRY_COUNT + 1))..."

  if rsync $RSYNC_OPTS "$SOURCE_DIR/" "$DESTINATION"; then
    log "INFO" "Transfer successful!"
    find "$SOURCE_DIR" -mindepth 2 -type d -empty -delete
    log "INFO" "Source files deleted after transfer via rsync, empty directories cleaned."
    
    # === JELLYFIN SCAN ===
    log "INFO" "Triggering library scan..."
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "$JELLY_API_URL" -H "Authorization: MediaBrowser Token=$JELLY_API_KEY")

    if [ "$HTTP_STATUS" -eq 204 ]; then
      log "INFO" "Library refresh initiated successfully!"
    else
      log "ERR" "Failed to initiate library refresh. Code: $HTTP_STATUS"
    fi

    exit 0
  else
    log "ERR" "Transfer attempt $((RETRY_COUNT + 1)) failed."
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log "INFO" "Retrying in 10 seconds..."
    sleep 10
  fi
done

log "ERR" "All transfer attempts failed. Files have not been deleted."
exit 1
