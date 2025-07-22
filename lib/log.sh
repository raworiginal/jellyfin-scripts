#!/bin/bash

# Default tag for logger
LOG_TAG="${LOG_TAG:-$(basename "$0")}"
LOG_VERBOSE="${LOG_VERBOSE:-false}"

log() {
  local level="$1"
  shift
  local message="$*"

  logger - "user.${level,,}" -t "$LOG_TAG" "$message"

  #Option to print to terminal
  if [[ "$LOG_VERBOSE" == "true" ]]; then
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp][$level] $message"
  fi
}
