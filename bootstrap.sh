#!/bin/bash
# Clinic Catalyst - full machine bootstrap for a new operator (e.g. Alicia).
# Provisions the NATIVE environment the CC skills actually need, installs the CC skills,
# and scaffolds the .env. Run AFTER: Homebrew + `gh auth login` done.
# Usage:  curl -fsSL https://clinic-catalyst-au.github.io/cc-onboard/bootstrap.sh | bash
set -uo pipefail
say(){ printf "\n\033[1;36m%s\033[0m\n" "$*"; }

say "Clinic Catalyst machine setup - starting"

# 0) Homebrew
if ! command -v brew >/dev/null 2>&1; then
  say "[1/8] Installing Homebrew"; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
else say "[1/8] Homebrew ok"; fi
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true

# 1) CLI toolchain the CC skills call (node, python, git, ffmpeg, gh, image tools, media)
say "[2/8] Core tools (node, python, git, ffmpeg, gh, imagemagick, yt-dlp)"
brew install node python git ffmpeg gh imagemagick yt-dlp 2>/dev/null
# superwhisper = talk-to-type into any field incl the terminal (so you dictate instead of typing).
# After install: open it once, grant Microphone + Accessibility, set a push-to-talk hotkey.
say "      + superwhisper (dictation app)"
brew install --cask superwhisper 2>/dev/null || echo "  (superwhisper cask skipped - install from superwhisper.com if needed)"

# 2) Python packages (Pillow=image compositing, requests=API calls, playwright=deck-to-pdf + scraping)
# Homebrew python is PEP-668 "externally managed" so plain pip fails. --break-system-packages is the supported fix.
# NOTE: errors are NOT silenced here - a failed pip means CC image/scrape skills won't work, so it must be loud.
say "[3/8] Python packages (Pillow, requests, playwright)"
python3 -m pip install --quiet --upgrade --break-system-packages pip 2>/dev/null || true
if python3 -m pip install --break-system-packages Pillow requests playwright; then
  echo "  python packages installed"
else
  echo "  !! pip install FAILED - CC image/scrape/PDF skills will not work. Fix this before using Claude."
fi
# mlx-whisper = fast on-device transcription on Apple Silicon (CC video skills: cc-find-clip / cc-content-pipeline).
# Apple-Silicon only, so failure is non-fatal - those skills fall back to the OpenAI Whisper API.
python3 -m pip install --quiet --break-system-packages mlx-whisper 2>/dev/null \
  && echo "  mlx-whisper installed (fast on-device transcription)" \
  || echo "  (mlx-whisper skipped - Intel Mac? CC video skills will use the OpenAI Whisper API instead)"

# 3) Claude Code
say "[4/8] Claude Code"
npm install -g @anthropic-ai/claude-code 2>/dev/null
echo 'export PATH="$PATH:/opt/homebrew/bin"' >> ~/.zprofile 2>/dev/null

# 4) gh as git credential helper (no username prompts) + clone the CC system
say "[5/8] GitHub auth helper + clone cc-aios"
if gh auth status >/dev/null 2>&1; then gh auth setup-git
else echo "  !! Run 'gh auth login' first, then re-run this. Skipping clone."; fi
mkdir -p ~/Systems
if [ ! -d ~/Systems/cc-aios/.git ]; then gh repo clone Clinic-Catalyst-AU/cc-aios ~/Systems/cc-aios 2>/dev/null && echo "  cloned cc-aios"; \
  else git -C ~/Systems/cc-aios pull -q && echo "  updated cc-aios"; fi

# 5) Install CC skills + CC CLAUDE.md
say "[6/8] Install CC skills + CLAUDE.md"
[ -x ~/Systems/cc-aios/bin/apply-to-machine.sh ] && ~/Systems/cc-aios/bin/apply-to-machine.sh
[ -f ~/CLAUDE.md ] || cp ~/Systems/cc-aios/CLAUDE.md ~/CLAUDE.md 2>/dev/null
# cc-reel render engine (the /cc-reel skill drives this Remotion project). NON-FATAL - heavy
# npm install must never break the rest of the install; /cc-reel can install it on demand.
if [ -d ~/Systems/cc-aios/reel-render ]; then
  say "      + cc-reel render engine (Remotion deps - heavy)"
  ( cd ~/Systems/cc-aios/reel-render && npm install ) >/dev/null 2>&1 \
    && echo "  cc-reel-render ready" \
    || echo "  (cc-reel-render deps not installed - run 'cd ~/Systems/cc-aios/reel-render && npm install' before first /cc-reel)"
fi

# 6) Playwright (CC skills scrape sites + screenshot demos) + register the Playwright MCP
say "[7/8] Playwright browser + MCP"
npx --yes playwright install chromium 2>/dev/null
# also install the browser for the PYTHON playwright package (deck-to-pdf uses python, not node)
python3 -m playwright install chromium 2>/dev/null || true
python3 - <<'PY' 2>/dev/null
import json,os
p=os.path.expanduser("~/.claude/settings.json")
s={}
if os.path.exists(p):
    try: s=json.load(open(p))
    except: s={}
s.setdefault("mcpServers",{}).setdefault("playwright",{"command":"npx","args":["@playwright/mcp@latest"]})
json.dump(s,open(p,"w"),indent=2)
print("  Playwright MCP added to ~/.claude/settings.json")
PY

# 7) .env scaffold (the CC skills read ~/Systems/BusinessOps/.env). Real values come from Kelly (shared) or your own.
say "[8/8] .env scaffold"
mkdir -p ~/Systems/BusinessOps
ENVF=~/Systems/BusinessOps/.env
if [ ! -f "$ENVF" ]; then
cat > "$ENVF" <<'EOF'
# Clinic Catalyst .env - fill these in (Kelly sends the SHARED ones securely; OWN = make your own)
# Key NAMES must match exactly - the skills read these exact names.
# --- SHARED (Kelly provides) ---
CC_GHL_PIT=
CC_GHL_LOCATION_ID=
CC_SUPABASE_URL=
CC_SUPABASE_KEY=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
# --- OWN (your own keys) ---
GEMINI_KEY=
OPENAI_API_KEY=
FIREFLIES_API_KEY=
EOF
echo "  created $ENVF (fill in the values)"
else echo "  $ENVF already exists - left it"; fi

# 8) Self-check - prove the toolchain the CC skills actually need is really there (don't report DONE on a broken install)
say "Self-check - verifying the CC skills can actually run"
FAIL=0
for c in brew node git gh ffmpeg convert npx claude; do
  if command -v "$c" >/dev/null 2>&1; then echo "  ok   $c"; else echo "  MISSING  $c"; FAIL=1; fi
done
for m in PIL requests playwright; do
  if python3 -c "import $m" >/dev/null 2>&1; then echo "  ok   python:$m"; else echo "  MISSING  python:$m"; FAIL=1; fi
done
# the repo + skills must actually be there - catches a skipped clone (e.g. gh auth not done first)
if [ -d ~/Systems/cc-aios/.git ]; then echo "  ok   cc-aios repo"; else echo "  MISSING  cc-aios repo (run 'gh auth login' then re-run this)"; FAIL=1; fi
if [ -d ~/.claude/skills/cc-prospect ]; then echo "  ok   CC skills installed"; else echo "  MISSING  CC skills (the repo did not clone, so nothing installed)"; FAIL=1; fi
if [ -f ~/Systems/BusinessOps/.env ]; then echo "  ok   .env scaffold"; else echo "  MISSING  .env scaffold"; FAIL=1; fi

if [ "$FAIL" -eq 0 ]; then
  say "DONE - Clinic Catalyst environment installed and verified"
else
  say "DONE WITH PROBLEMS - one or more tools above are MISSING. Tell Kelly before using the CC skills."
fi
echo "Next:  1) fill ~/Systems/BusinessOps/.env   2) run 'claude' and log in to YOUR Anthropic account   3) accept the shared Dropbox folder   4) try /cc-prospect"
