#!/bin/bash
# Clinic Catalyst - ONE-LINE clinic install (Mac). Sets up the whole baseline + the skill pack.
# Usage:  curl -fsSL https://clinic-catalyst-au.github.io/cc-onboard/clinic-bootstrap.sh | bash
# Installs: Homebrew, Node, Python, Claude Code, then downloads the Clinic Catalyst skill pack and
# runs its installer (ffmpeg + imagemagick + python packages + mlx-whisper + the 19 skills + ~/Clinic).
set -uo pipefail
say(){ printf "\n\033[1;36m%s\033[0m\n" "$*"; }

say "Clinic Catalyst install - starting (this takes ~25-45 min, mostly downloads)"

# 1) Homebrew (arch-aware: Apple Silicon /opt/homebrew, Intel /usr/local)
if ! command -v brew >/dev/null 2>&1; then
  say "[1/4] Installing Homebrew"; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else say "[1/4] Homebrew ok"; fi
for BP in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$BP" ]; then eval "$("$BP" shellenv)"; grep -q "$BP shellenv" ~/.zprofile 2>/dev/null || echo "eval \"\$($BP shellenv)\"" >> ~/.zprofile; break; fi
done

# 2) Node + Python + Claude Code
say "[2/4] Node, Python + Claude Code"
brew install node python git >/dev/null 2>&1 || echo "  (brew base tools issue)"
npm install -g @anthropic-ai/claude-code >/dev/null 2>&1 && echo "  Claude Code installed" || echo "  (Claude Code install issue - check Node)"
echo 'export PATH="$PATH:/opt/homebrew/bin"' >> ~/.zprofile 2>/dev/null || true

# 3) Download the skill pack + run its installer (it provisions ffmpeg/imagemagick/python + the skills + ~/Clinic)
say "[3/4] Clinic Catalyst skill pack"
TMP=$(mktemp -d); cd "$TMP"
if curl -fsSL https://clinic-catalyst-au.github.io/cc-onboard/cc-clinic-pack.zip -o pack.zip && unzip -q pack.zip; then
  bash cc-clinic-pack/INSTALL.sh
else
  echo "  !! could not download the skill pack - check your internet, then re-run this command."
fi

# 4) Self-check
say "[4/4] Self-check"
FAIL=0
for c in brew node git ffmpeg convert claude; do command -v "$c" >/dev/null 2>&1 && echo "  ok   $c" || { echo "  MISSING  $c"; FAIL=1; }; done
for m in PIL requests; do python3 -c "import $m" >/dev/null 2>&1 && echo "  ok   python:$m" || { echo "  MISSING  python:$m"; FAIL=1; }; done
[ -d "$HOME/.claude/skills/cc-content-engine" ] && echo "  ok   CC skills installed" || { echo "  MISSING  CC skills"; FAIL=1; }

if [ "$FAIL" -eq 0 ]; then say "DONE - everything installed and verified"; else say "DONE WITH PROBLEMS - tell your facilitator what is MISSING above"; fi
echo "Next:  1) close + reopen Terminal   2) type 'claude' and sign in + paste your API key   3) open ~/Clinic and run /cc-resonance"
