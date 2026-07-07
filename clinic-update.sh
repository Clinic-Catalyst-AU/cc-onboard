#!/bin/bash
# Clinic Catalyst - UPDATE (Mac). One command to pull the latest skills onto this machine.
# Re-downloads the live clinic pack and MERGES the skills into ~/.claude/skills (non-destructive:
# it updates CC skills and adds new ones, and never touches your Business Brain or other skills).
# Clinics install from the pack zip (no git repo), so this is the right update path for them -
# NOT the operator git-pull command.
set -uo pipefail
say(){ printf "\n\033[1;36m%s\033[0m\n" "$*"; }

say "Clinic Catalyst update - fetching the latest skills"
cd "$HOME/Downloads" 2>/dev/null || cd "$HOME"

if curl -fsSL https://clinic-catalyst-au.github.io/cc-onboard/cc-clinic-pack.zip -o ccpack-update.zip && unzip -oq ccpack-update.zip; then
  mkdir -p "$HOME/.claude/skills"
  rsync -a cc-clinic-pack/skills/ "$HOME/.claude/skills/"
  N=$(ls -1 "$HOME/.claude/skills" | grep -c '^cc-')
  rm -f ccpack-update.zip
  echo "  updated - $N CC skills now installed"
  echo ""
  echo "DONE. Now CLOSE and REOPEN Claude Code so the new skills register:"
  echo "  /cc-nurture-sequence  /cc-thankyou-page  /cc-fb-leadform"
  echo "Your Business Brain (~/Clinic) and your own work were NOT touched - this only refreshes the skills."
else
  echo "  !! could not download the pack - check your internet, then re-run this command."
fi
