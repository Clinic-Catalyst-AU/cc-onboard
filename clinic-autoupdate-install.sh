#!/bin/bash
# Clinic Catalyst - TURN ON AUTO-UPDATE (Mac). Run this ONCE per machine.
# It installs a background agent that refreshes the CC skills automatically -
# once right now, then every day - so nobody ever runs an update command again.
# Non-destructive: only refreshes CC skills, never touches the Business Brain.
set -uo pipefail
say(){ printf "\n\033[1;36m%s\033[0m\n" "$*"; }

LABEL="com.cliniccatalyst.autoupdate"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UPDATE_URL="https://clinic-catalyst-au.github.io/cc-onboard/clinic-update.sh"
LOG="$HOME/.claude/cc-autoupdate.log"

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.claude"

# LaunchAgent: RunAtLoad runs it immediately on install; StartCalendarInterval repeats it daily at 07:30.
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>/usr/bin/curl -fsSL $UPDATE_URL | /bin/bash >> "$LOG" 2>&1</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>7</integer><key>Minute</key><integer>30</integer></dict>
</dict>
</plist>
PLISTEOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

say "Auto-update is ON."
echo "  - It just ran once now (log: $LOG)"
echo "  - It will refresh the skills automatically every day at 7:30am"
echo "  - No one needs to run an update command again on this machine"
echo ""
echo "Last step: CLOSE and REOPEN Claude Code so the refreshed skills register."
