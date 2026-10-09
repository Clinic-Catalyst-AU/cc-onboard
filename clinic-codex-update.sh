#!/bin/bash
# Clinic Catalyst - UPDATE your skills for Codex (Mac).
# Usage:  curl -fsSL https://clinic-catalyst-au.github.io/cc-onboard/clinic-codex-update.sh | bash
# Refreshes ~/.agents/skills from the latest pack. Your ~/Clinic folder and AGENTS.md are left alone.
set -euo pipefail
T="$(mktemp -d)"
curl -fsSL https://clinic-catalyst-au.github.io/cc-onboard/cc-clinic-pack.zip -o "$T/pack.zip"
unzip -q "$T/pack.zip" -d "$T"
mkdir -p "$HOME/.agents/skills"
rsync -a "$T/cc-clinic-pack/skills/" "$HOME/.agents/skills/"
mkdir -p "$HOME/Clinic/Business-Brain/brand-assets" "$HOME/Clinic/Content" "$HOME/Clinic/Emails" "$HOME/Clinic/Ads"
[ -f "$HOME/Clinic/AGENTS.md" ] || cp "$T/cc-clinic-pack/templates/clinic-CLAUDE.md" "$HOME/Clinic/AGENTS.md"
echo "DONE - $(ls -d "$HOME"/.agents/skills/cc-* | wc -l | tr -d ' ') Clinic Catalyst skills up to date."
echo "Next: close Codex if it is open, then start it again:  cd ~/Clinic && codex"
