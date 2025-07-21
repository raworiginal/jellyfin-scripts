#!/bin/bash
set -euo pipefail

# === CONFIG ===
export LOG_TAG="compressBatch"
export LOG_VERBOSE=true

# === IMPORT HELPERS ===
source "$HOME/Documents/GitHub/scripts/lib/log.sh"
source "$HOME/Documents/GitHub/scripts/lib/suspend-guard.sh"
source "$HOME/Documents/GitHub/scripts/lib/email.sh"

# === Summary Email ===
compose_summary() {
  # Get the line number of the last "Compression started" log entry
  START_LINE="$(journalctl -t "$LOG_TAG" | grep -n "Compression started at" | tail -n 1 | cut -d: -f1)"

  # If no such line is found, log a warning and skip the summary
  if [[ -z "$START_LINE" ]]; then
    log "WARN" "No 'Compression started' entry found in journal. Skipping summary email."
    return
  fi

  # Get logs from that point to the end
  LOG_BODY="$(journalctl -t "$LOG_TAG" | tail -n +"$START_LINE")"

  # Construct a timestamped subject line
  EMAIL_SUBJECT="$(date +'%F_%H-%M-%S') - $(hostname) - $LOG_TAG summary"
  
  # Send the email using your helper function
  send_summary_email "$EMAIL_SUBJECT" "$LOG_BODY" "$EMAIL_RECIPIENT"
}

trap 'log "ERR" "Script failed at line $LINENO with code $?"' ERR
trap compose_summary EXIT

# === MODES ===
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  log "INFO" "Dry run mode enabled."
fi

# === ENV LOAD ===
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  source "$SCRIPT_DIR/.env"
else
  log "ERR" ".env file not found. Exiting."
  exit 1
fi

# === ENV VALIDATION ===
: "${SOURCE_DIR:?Missing SOURCE_DIR in .env}"
: "${OUTPUT_DIR:?Missing OUTPUT_DIR in .env}"

# === Ensure Output Structure ===
mkdir -p "$OUTPUT_DIR/Movies"
mkdir -p "$OUTPUT_DIR/TV"

log "INFO" "Compression started at $(date '+%F %T')"

# === FUNCTION: Compress or Copy a File ===
compress_file() {
  local input="$1"
  local output="$2"

  log "INFO" "========================================="
  log "INFO" "Evaluating: $input"

  if [[ ! -s "$input" ]]; then
    log "INFO" "⚠️ Skipping empty or missing file: $input"
    return
  fi

  local height
  height=$(mediainfo --Inform="Video;%Height%" "$input")

  if [[ "$height" =~ ^[0-9]+$ && "$height" -ge 1000 ]]; then
    log "INFO" "Detected Blu-ray (Height: $height). Compressing..."

    if [[ "$DRY_RUN" == true ]]; then
      log "INFO" "[Dry Run] Would compress: $input → $output"
    else
      if HandBrakeCLI --verbose=0 -i "$input" -o "$output" \
        -e nvenc_h265 -q 20 -E av_aac -B 192 \
        --all-audio \
        --audio-copy-mask aac --audio-fallback av_aac \
        --subtitle-lang-list eng --all-subtitles \
        --optimize; then
        log "INFO" "✅ Compressed: $output"
        #rm -f "$input"
      else
        log "ERR" "❌ Compression failed: $input"
      fi
    fi

  elif [[ "$height" =~ ^[0-9]+$ ]]; then
    log "INFO" "Detected DVD/lower quality (Height: $height). Moving file."

    if [[ "$DRY_RUN" == true ]]; then
      log "INFO" "[Dry Run] Would move: $input → $output"
    else
      if mv "$input" "$output"; then
        log "INFO" "✅ Moved: $output"
      else
        log "ERR" "❌ move failed: $input"
      fi
    fi

  else
    log "INFO" "⏭ Skipping: Unable to determine height for $input"
  fi

  log "INFO" "========================================="
}

# === MOVIES ===
mapfile -t movie_files < <(find "$SOURCE_DIR/Movies" -type f -name '*.mkv')

for file in "${movie_files[@]}"; do
  rel_path="${file#"$SOURCE_DIR"/Movies/}"
  movie_dir=$(dirname "$rel_path")
  movie_name=$(basename "$movie_dir")

  output_dir="$OUTPUT_DIR/Movies/$movie_name"
  mkdir -p "$output_dir"

  output_file="$output_dir/$movie_name.mkv"
  compress_file "$file" "$output_file"
done

# === TV SHOWS ===
mapfile -t tv_files < <(find "$SOURCE_DIR/TV" -type f -name '*.mkv')

for file in "${tv_files[@]}"; do
  rel_path="${file#"$SOURCE_DIR"/TV/}"
  base_name=$(basename "$file")
  sub_dir=$(dirname "$rel_path")

  output_dir="$OUTPUT_DIR/TV/$sub_dir"
  mkdir -p "$output_dir"

  output_file="$output_dir/$base_name"
  compress_file "$file" "$output_file"
done

log "INFO" "========================================="
log "INFO" "📦 Compression complete."
log "INFO" "Review logs with: journalctl -t $LOG_TAG"
log "INFO" "Finished at: $(date '+%F %T')"
log "INFO" "========================================="
log "INFO" "✅ compressBatch.sh completed successfully"

exit 0
