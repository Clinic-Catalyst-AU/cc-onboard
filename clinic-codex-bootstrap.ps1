# Clinic Catalyst - ONE-LINE clinic install for OpenAI CODEX (Windows, native - no WSL needed).
# Usage (PowerShell):  irm https://clinic-catalyst-au.github.io/cc-onboard/clinic-codex-bootstrap.ps1 | iex
# For clinics on a ChatGPT plan (Plus or Pro) instead of a Claude plan. Same tools and skill pack as
# clinic-bootstrap.ps1, but installs the Codex CLI (npm) instead of Claude Code, puts the skills in
# ~\.agents\skills (where Codex loads them) and writes ~\Clinic\AGENTS.md (Codex's rules file).
$ErrorActionPreference = 'Continue'

function Say($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }

function Refresh-Path {
  $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machine;$user"
}

Say "Clinic Catalyst install for Codex - starting (this takes ~25-45 min, mostly downloads)"

# 0) winget must exist (ships with Windows 11 and most Windows 10 22H2+ builds via App Installer)
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host "!! winget not found. Install 'App Installer' from the Microsoft Store (https://aka.ms/getwinget)," -ForegroundColor Red
  Write-Host "   then re-run this command." -ForegroundColor Red
  exit 1
}

# 1) Core tools via winget (Git, Node LTS, Python, ffmpeg). Each is independent/non-fatal so one
#    failure does not stop the rest - the self-check at the end catches anything that is missing.
Say "[1/4] Core tools (git, node, python, ffmpeg)"
$packages = @(
  @{ Id = 'Git.Git';           Name = 'git' },
  @{ Id = 'OpenJS.NodeJS.LTS'; Name = 'node' },
  @{ Id = 'Python.Python.3.12'; Name = 'python' },
  @{ Id = 'Gyan.FFmpeg';       Name = 'ffmpeg' }
)
foreach ($p in $packages) {
  Write-Host "  installing $($p.Name)..."
  winget install --id $($p.Id) -e --silent --accept-package-agreements --accept-source-agreements *> $null
}
Refresh-Path

# ffmpeg fallback: winget's Gyan.FFmpeg reliably installs but often lands OUTSIDE PATH
# (WinGet Links dir quirk). Deterministic fix: static binaries into .local\bin, which this
# script already persists on PATH. Caught by CI 6 Jul - do not remove.
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
  Write-Host "  ffmpeg not on PATH - installing static build to .local\bin"
  $ProgressPreference = 'SilentlyContinue'
  $bin = "$env:USERPROFILE\.local\bin"; New-Item -ItemType Directory -Force -Path $bin | Out-Null
  $zip = "$env:TEMP\ffmpeg.zip"
  Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile $zip -UseBasicParsing
  $dest = "$env:TEMP\ffmpeg-extract"; Expand-Archive -Path $zip -DestinationPath $dest -Force
  Get-ChildItem -Path $dest -Recurse -Include ffmpeg.exe,ffprobe.exe | ForEach-Object { Copy-Item $_.FullName $bin -Force }
  Refresh-Path
}

# 2) Codex CLI - OpenAI's official npm package (@openai/codex), installed globally with the Node
#    from step 1. No admin rights needed: npm's global folder is %APPDATA%\npm, which we make sure
#    is on the USER PATH so typing 'codex' works in every new window.
Say "[2/4] Codex"
Refresh-Path
if (Get-Command npm.cmd -ErrorAction SilentlyContinue) {
  # npm.cmd / codex.cmd, not npm / codex: Windows blocks the .ps1 shims under the default execution policy
  npm.cmd install -g @openai/codex *> $null
  $npmBin = Join-Path $env:APPDATA 'npm'
  $up = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($up -notlike "*$npmBin*") {
    [Environment]::SetEnvironmentVariable('Path', "$up;$npmBin", 'User')
    Write-Host "  added $npmBin to your PATH (codex command works in new windows)"
  }
  $env:Path = "$env:Path;$npmBin"
  if (Get-Command codex.cmd -ErrorAction SilentlyContinue) { Write-Host "  Codex installed" }
  else { Write-Host "  !! Codex install did not finish - close PowerShell, open a new one and re-run this command" -ForegroundColor Yellow }
} else {
  Write-Host "  !! npm not found yet - close PowerShell, open a new one and re-run this command (Node needs a fresh window)" -ForegroundColor Yellow
}
# %USERPROFILE%\.local\bin holds the ffmpeg fallback - persist it on the USER PATH, harmless if already there.
$localBin = Join-Path $env:USERPROFILE '.local\bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$localBin*") {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$localBin", 'User')
  Write-Host "  added $localBin to your PATH"
}
Refresh-Path
$env:Path = "$env:Path;$localBin"

# 3) Python deps for the skills (Pillow=covers, requests=API calls, playwright=scraping).
#    NOTE: python.org's Windows build is not "externally managed" like Homebrew's, so plain
#    pip works here - no --break-system-packages needed (that is a Mac-only wrinkle).
Say "[3/4] Python packages (Pillow, requests, playwright, faster-whisper)"
$py = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } elseif (Get-Command py -ErrorAction SilentlyContinue) { 'py' } else { $null }
if ($py) {
  & $py -m pip install --quiet --user Pillow requests playwright faster-whisper
  if ($LASTEXITCODE -eq 0) { Write-Host "  python packages ok" } else { Write-Host "  !! python deps failed - cc-cover/scrape skills need Pillow+requests" -ForegroundColor Yellow }
  # faster-whisper = keyless on-device transcription for /cc-reel + /cc-find-clip captions
  # (mlx-whisper is Apple Silicon only). Pre-download the model NOW on home wifi so the
  # first caption run at the workshop does not stall on a ~500MB download.
  Write-Host "  pre-downloading the caption model (one-off, ~500MB)..."
  # stderr is silenced INSIDE python - PS 5.1 turns redirected stderr into NativeCommandError
  & $py -c "import sys, os; sys.stderr = open(os.devnull, 'w'); from faster_whisper import WhisperModel; WhisperModel('small', compute_type='int8')"
  if ($LASTEXITCODE -eq 0) { Write-Host "  caption model cached - /cc-reel captions work offline, no API key needed" }
  else { Write-Host "  (caption model download skipped - it will download on first /cc-reel run instead)" -ForegroundColor Yellow }
} else {
  Write-Host "  !! python not found on PATH - re-open PowerShell and re-run this command" -ForegroundColor Yellow
}
# superwhisper is Mac-only - Windows folks use the built-in Win+H voice typing for dictation.

# 4) Download the skill pack + set it up (skills, ~/Clinic workspace, reel engine)
Say "[4/4] Clinic Catalyst skill pack"
$tmp = Join-Path $env:TEMP "cc-clinic-pack-install"
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tmp | Out-Null
$zipPath = Join-Path $tmp "pack.zip"
try {
  Invoke-WebRequest -Uri "https://clinic-catalyst-au.github.io/cc-onboard/cc-clinic-pack.zip" -OutFile $zipPath -UseBasicParsing
  Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
  $packDir = Join-Path $tmp "cc-clinic-pack"

  # Skills -> ~/.claude/skills
  $skillsDest = Join-Path $HOME ".claude\skills"
  New-Item -ItemType Directory -Path $skillsDest -Force | Out-Null
  Copy-Item -Path (Join-Path $packDir "skills\*") -Destination $skillsDest -Recurse -Force
  $skillCount = (Get-ChildItem (Join-Path $packDir "skills")).Count
  # Codex loads skills from ~\.agents\skills
  $agentSkills = Join-Path $HOME ".agents\skills"
  New-Item -ItemType Directory -Path $agentSkills -Force | Out-Null
  Copy-Item -Path (Join-Path $packDir "skills\*") -Destination $agentSkills -Recurse -Force
  Write-Host "  installed $skillCount skills for Codex"

  # Workspace -> ~/Clinic (mirrors scaffold-clinic-workspace.sh)
  $clinic = Join-Path $HOME "Clinic"
  New-Item -ItemType Directory -Path (Join-Path $clinic "Business-Brain\brand-assets") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $clinic "Content") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $clinic "Emails") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $clinic "Ads") -Force | Out-Null

  $claudeMd = Join-Path $clinic "CLAUDE.md"
  $template = Join-Path $packDir "templates\clinic-CLAUDE.md"
  if (-not (Test-Path $claudeMd)) {
    if (Test-Path $template) { Copy-Item $template $claudeMd; Write-Host "  + CLAUDE.md (from template)" }
    else { Write-Host "  !! template not found in pack - add CLAUDE.md manually" }
  } else { Write-Host "  CLAUDE.md already exists - left it" }
  $agentsMd = Join-Path $clinic "AGENTS.md"
  if (-not (Test-Path $agentsMd)) {
    if (Test-Path $template) { Copy-Item $template $agentsMd; Write-Host "  + AGENTS.md (Codex rules, from template)" }
  } else { Write-Host "  AGENTS.md already exists - left it" }

  $bbReadme = Join-Path $clinic "Business-Brain\README.md"
  if (-not (Test-Path $bbReadme)) {
    @"
# Business Brain - your foundation lives here

These files are the spine of your whole system. Every skill reads from here.
They get created when you run the foundation skills (do this first):

1. Ask Codex: build my clinic's resonance messaging (the cc-resonance skill) -> writes resonance-messaging.md
2. Ask Codex: build my brand guide (the cc-brand-guide skill)               -> writes brand-guide.md

Then the system runs: content, follow-up and ads all read these and write
into ../Content, ../Emails and ../Ads. Do not rename these files.

Expected files: brand-guide.md, resonance-messaging.md, offers.md,
services-machines.md, concerns.md, team.md, strategy.md

Visual brand lives in brand-assets/ - drop these in so covers and reels
render in YOUR branding (all optional, sensible fallbacks if absent):
  brand-assets/logo.png            your logo (transparent PNG)
  brand-assets/headline-font.ttf   your headline font
  brand-assets/body-font.ttf       your body font
  brand-assets/accent.txt          your accent colour as one hex line, e.g. #C9A24B
"@ | Out-File -FilePath $bbReadme -Encoding utf8
    Write-Host "  + Business-Brain/README.md (signpost)"
  }

  # Reel engine (for /cc-reel)
  $reelSrc = Join-Path $packDir "reel-render"
  if ((Get-Command npm.cmd -ErrorAction SilentlyContinue) -and (Test-Path $reelSrc)) {
    $reelDest = Join-Path $clinic ".reel-render"
    New-Item -ItemType Directory -Path $reelDest -Force | Out-Null
    Copy-Item -Path (Join-Path $reelSrc '*') -Destination $reelDest -Recurse -Force -ErrorAction SilentlyContinue
    Push-Location $reelDest
    npm.cmd install *> $null
    Pop-Location
    Write-Host "  reel engine ready"
  } else {
    Write-Host "  (node/npm not found - /cc-reel needs it; re-open PowerShell then run 'npm install' in $clinic\.reel-render)"
  }
} catch {
  Write-Host "  !! could not download/install the skill pack - check your internet, then re-run this command." -ForegroundColor Red
  Write-Host "     $($_.Exception.Message)" -ForegroundColor Red
}

# Self-check
Say "Self-check"
$fail = $false
foreach ($c in @('git','node','python','ffmpeg','codex.cmd')) {
  if (Get-Command $c -ErrorAction SilentlyContinue) { Write-Host "  ok   $c" } else { Write-Host "  MISSING  $c" -ForegroundColor Yellow; $fail = $true }
}
foreach ($m in @('PIL','requests','faster_whisper')) {
  if (-not $py) { Write-Host "  MISSING  python:$m (python not found)" -ForegroundColor Yellow; $fail = $true; continue }
  & $py -c "import sys, os; sys.stderr = open(os.devnull, 'w'); import $m"
  if ($LASTEXITCODE -eq 0) { Write-Host "  ok   python:$m" } else { Write-Host "  MISSING  python:$m" -ForegroundColor Yellow; $fail = $true }
}
if ((Test-Path (Join-Path $HOME ".agents\skills\cc-content-engine")) -and (Test-Path (Join-Path $HOME "Clinic\AGENTS.md"))) { Write-Host "  ok   CC skills installed" } else { Write-Host "  MISSING  CC skills" -ForegroundColor Yellow; $fail = $true }

if (-not $fail) { Say "DONE - everything installed and verified" } else { Say "DONE WITH PROBLEMS - tell your facilitator what is MISSING above" }
Write-Host "Next:  1) close + reopen PowerShell   2) type: cd ~\Clinic; codex.cmd   3) choose 'Sign in with ChatGPT'"
Write-Host "       4) ask in plain words, e.g. 'Use the cc-resonance skill to learn my clinic'"
