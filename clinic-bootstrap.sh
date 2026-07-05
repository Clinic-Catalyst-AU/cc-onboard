#!/bin/bash
# Clinic Catalyst - ONE-LINE clinic install (Mac). Sets up the whole baseline + the skill pack.
# Usage:  curl -fsSL https://clinic-catalyst-au.github.io/cc-onboard/clinic-bootstrap.sh | bash
# ORDER MATTERS: Claude Code first (official installer, zero dependencies - working in ~2 min),
# THEN Homebrew, THEN the tools + skill pack churn in the background (~25-45 min, mostly downloads).
# On macOS 13 or older (Homebrew Tier 2, no bottles) it falls back to the official installers:
# nodejs.org pkg + pip on the system python. Video tools need macOS 14+.
set -uo pipefail
say(){ printf "\n\033[1;36m%s\033[0m\n" "$*"; }

say "Clinic Catalyst install - starting (Claude Code first, then the tools; ~25-45 min total)"

# 0) macOS version - 13 or older means Homebrew has no pre-built bottles and brew installs fail
TIER2=0
MACOS_MAJOR=$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)
if [ -n "${MACOS_MAJOR:-}" ] && [ "$MACOS_MAJOR" -le 13 ] 2>/dev/null; then
  TIER2=1
  say "This Mac runs macOS $MACOS_MAJOR - using the official installers instead of Homebrew."
  echo "  Everything works except the video skills (ffmpeg) - those unlock when you upgrade macOS."
fi

# 1) Claude Code FIRST - the official installer needs nothing else (no Homebrew, no Node).
#    You have a working 'claude' inside ~2 minutes while the rest downloads.
say "[1/4] Claude Code"
if curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1; then
  echo "  Claude Code installed"
else
  echo "  (official installer had an issue - will retry via npm once Node is in)"
fi
export PATH="$PATH:$HOME/.local/bin"
grep -q '.local/bin' ~/.zprofile 2>/dev/null || echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.zprofile

# 2) Homebrew (arch-aware: Apple Silicon /opt/homebrew, Intel /usr/local). Still installed on old
#    Macs - its installer provides the Command Line Tools (git + python3) even when bottles fail.
if ! command -v brew >/dev/null 2>&1; then
  say "[2/4] Installing Homebrew"; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else say "[2/4] Homebrew ok"; fi
for BP in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$BP" ]; then eval "$("$BP" shellenv)"; grep -q "$BP shellenv" ~/.zprofile 2>/dev/null || echo "eval \"\$($BP shellenv)\"" >> ~/.zprofile; break; fi
done

# 3) Node + Python + the skill pack (its installer provisions ffmpeg/imagemagick/python + skills + ~/Clinic)
say "[3/4] Node, Python + the Clinic Catalyst skill pack"
if [ "$TIER2" -eq 0 ]; then
  brew install node python git >/dev/null 2>&1 || echo "  (brew base tools issue)"
fi
# Fallback for old Macs OR any Mac where the brew install silently failed to produce node:
if ! command -v node >/dev/null 2>&1; then
  echo "  Installing Node from nodejs.org (you may be asked for your Mac password)"
  NODE_PKG=$(curl -fsSL https://nodejs.org/dist/latest-v22.x/ | grep -o 'node-v[0-9.]*\.pkg' | head -1)
  if [ -n "$NODE_PKG" ] && curl -fsSL "https://nodejs.org/dist/latest-v22.x/$NODE_PKG" -o /tmp/cc-node.pkg; then
    sudo installer -pkg /tmp/cc-node.pkg -target / >/dev/null && echo "  Node installed (official pkg)" || echo "  (Node pkg install issue)"
    rm -f /tmp/cc-node.pkg
    export PATH="/usr/local/bin:$PATH"
  else echo "  (could not download Node from nodejs.org)"; fi
fi
# npm fallback only if the official Claude installer failed in step 1
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
  npm install -g @anthropic-ai/claude-code >/dev/null 2>&1 && echo "  Claude Code installed (npm fallback)" || echo "  (Claude Code still missing - flag your facilitator)"
fi
echo 'export PATH="$PATH:/opt/homebrew/bin"' >> ~/.zprofile 2>/dev/null || true
TMP=$(mktemp -d); cd "$TMP"
if curl -fsSL https://clinic-catalyst-au.github.io/cc-onboard/cc-clinic-pack.zip -o pack.zip && unzip -q pack.zip; then
  bash cc-clinic-pack/INSTALL.sh
else
  echo "  !! could not download the skill pack - check your internet, then re-run this command."
fi
# Python package rescue - covers old Macs where the pack's brew-python route failed.
# System/CLT python takes plain pip; brew python needs --break-system-packages (PEP 668).
if ! python3 -c "import PIL, requests" >/dev/null 2>&1; then
  python3 -m pip install --user pillow requests >/dev/null 2>&1 || \
  python3 -m pip install --user --break-system-packages pillow requests >/dev/null 2>&1 || true
fi

# 4) Self-check
say "[4/4] Self-check"
FAIL=0
for c in node git claude; do command -v "$c" >/dev/null 2>&1 && echo "  ok   $c" || { echo "  MISSING  $c"; FAIL=1; }; done
for c in brew ffmpeg convert; do
  if command -v "$c" >/dev/null 2>&1; then echo "  ok   $c"
  elif [ "$TIER2" -eq 1 ]; then echo "  skipped   $c (video tools need macOS 14+ - everything else works)"
  else echo "  MISSING  $c"; FAIL=1; fi
done
for m in PIL requests; do python3 -c "import $m" >/dev/null 2>&1 && echo "  ok   python:$m" || { echo "  MISSING  python:$m"; FAIL=1; }; done
[ -d "$HOME/.claude/skills/cc-content-engine" ] && echo "  ok   CC skills installed" || { echo "  MISSING  CC skills"; FAIL=1; }

if [ "$FAIL" -eq 0 ]; then say "DONE - everything installed and verified"; else say "DONE WITH PROBLEMS - tell your facilitator what is MISSING above"; fi
[ "$TIER2" -eq 1 ] && echo "Note: this Mac runs macOS $MACOS_MAJOR - when you upgrade macOS, re-run this one command and the video skills switch on."
echo "Next:  1) close + reopen Terminal   2) type 'claude' and sign in + paste your API key   3) open ~/Clinic and run /cc-resonance"
