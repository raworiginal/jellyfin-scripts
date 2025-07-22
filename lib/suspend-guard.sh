#!/bin/bash

# Prevents GNOME suspend and wraps in systemd-inhibit

# Relaunch inside of systemd-inhibit if not running already

if [[ -z "${INHIBIT_RUNNING:-}" ]]; then
  echo "Launching under systemd-inhibit..."
  SCRIPT_PATH=$(realpath "$0")
  exec env INHIBIT_RUNNING=1 systemd-inhibit \
    --what=handle-lid-switch:handle-power-key:handle-suspend-key:idle \
    --why="Long-running task in progress..." \
    "$SCRIPT_PATH" "$@"
fi

# Disable GNOME auto-suspend (if available)
if command -v gsettings &>/dev/null; then
  ORIGINAL_SLEEP_SETTING=$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type)
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'

  restore_suspend_setting() {
    echo "Restoring GNOME suspend setting to $ORIGINAL_SLEEP_SETTING"
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "$ORIGINAL_SLEEP_SETTING"
  }

  
fi
    
