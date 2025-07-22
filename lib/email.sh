#!/bin/bash

# Send an email summary using mailx + msmtp
# Usage: send_email_summary "Subject line" "Body test" ["recipient@email.com"]



send_summary_email() {
  local subject="$1"
  local body="$2"
  local recipient="${3:-$DEFAULT_EMAIL}"

  echo "$body" | mail -s "$subject" "$recipient"
}
