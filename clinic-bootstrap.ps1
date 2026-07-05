# Clinic Catalyst - ONE-LINE clinic install (Windows, native - no WSL needed).
# Usage (PowerShell):  irm https://clinic-catalyst-au.github.io/cc-onboard/clinic-bootstrap.ps1 | iex
# Installs: winget packages (Git, Node, Python, ffmpeg), Claude Code (native installer), then
# downloads the Clinic Catalyst skill pack and sets it up (python deps + the 19 skills + ~/Clinic).
$ErrorActionPreference = 'Continue'

function Say($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }

function Refresh-Path {
  $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machine;$user"
}

Say "Clinic Catalyst install - starting (this takes ~25-45 min, mostly downloads)"

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

# 2) Claude Code (native installer - no WSL, no admin rights needed)
Say "[2/4] Claude Code"
try {
  Invoke-Expression (Invoke-RestMethod https://claude.ai/install.ps1)
  Write-Host "  Claude Code installed"
} catch {
  Write-Host "  !! Claude Code install failed - see https://code.claude.com/docs/en/setup for manual steps" -ForegroundColor Yellow
}
Refresh-Path

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
  & $py -c "from faster_whisper import WhisperModel; WhisperModel('small', compute_type='int8')" 2>$null
  if ($LASTEXITCODE -eq 0) { Write-Host "  caption model cached - /cc-reel captions work offline, no API key needed" }
  else { Write-Host "  (caption model download skipped - it will download on first /cc-reel run instead)" -ForegroundColor Yellow }
} else {
  Write-Host "  !! python not found on PATH - re-open PowerShell and re-run this command" -ForegroundColor Yellow
}
# superwhisper is Mac-only - Windows folks use the built-in Win+H voice typing for dictation.

# 3b) MCP servers two of the 19 skills need. Neither is set up by the Mac installer either -
# this is a real gap, not a Windows-only one. Registering these makes /cc-ad-spy work; the
# GHL push in /cc-content-engine still needs the clinic's OWN GoHighLevel token pasted in
# (every clinic has a different GHL sub-account - there is no single token to ship in an installer).
Say "MCP servers (playwright for /cc-ad-spy, gohighlevel for the /cc-content-engine social push)"
# NOTE: plain ConvertFrom-Json (no -AsHashtable) on purpose - stock Windows ships PowerShell 5.1,
# which does not have -AsHashtable (that needs PS 6+). PSCustomObject + Add-Member works on both.
$claudeJsonPath = Join-Path $HOME ".claude.json"
try {
  $cfg = if (Test-Path $claudeJsonPath) { Get-Content $claudeJsonPath -Raw | ConvertFrom-Json } else { New-Object PSObject }
  if (-not ($cfg.PSObject.Properties.Name -contains 'mcpServers')) {
    $cfg | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue (New-Object PSObject)
  }
  if (-not ($cfg.mcpServers.PSObject.Properties.Name -contains 'playwright')) {
    $playwright = New-Object PSObject
    $playwright | Add-Member -NotePropertyName 'command' -NotePropertyValue 'npx'
    $playwright | Add-Member -NotePropertyName 'args' -NotePropertyValue @('-y', '@playwright/mcp@latest')
    $cfg.mcpServers | Add-Member -NotePropertyName 'playwright' -NotePropertyValue $playwright
    Write-Host "  + playwright MCP registered (powers /cc-ad-spy)"
  } else { Write-Host "  playwright MCP already registered - left it" }
  if (-not ($cfg.mcpServers.PSObject.Properties.Name -contains 'gohighlevel')) {
    $ghlEnv = New-Object PSObject
    $ghlEnv | Add-Member -NotePropertyName 'BEARER_TOKEN_BEARERAUTH' -NotePropertyValue ''
    $ghlEnv | Add-Member -NotePropertyName 'BEARER_TOKEN_BEARER' -NotePropertyValue ''
    $ghl = New-Object PSObject
    $ghl | Add-Member -NotePropertyName 'command' -NotePropertyValue 'npx'
    $ghl | Add-Member -NotePropertyName 'args' -NotePropertyValue @('-y', '@drausal/gohighlevel-mcp')
    $ghl | Add-Member -NotePropertyName 'env' -NotePropertyValue $ghlEnv
    $cfg.mcpServers | Add-Member -NotePropertyName 'gohighlevel' -NotePropertyValue $ghl
    Write-Host "  + gohighlevel MCP registered (empty token - see 'Next' below to finish this)"
  } else { Write-Host "  gohighlevel MCP already registered - left it" }
  $cfg | ConvertTo-Json -Depth 10 | Set-Content $claudeJsonPath
} catch {
  Write-Host "  !! could not update $claudeJsonPath - add the playwright/gohighlevel MCP servers manually if /cc-ad-spy or the GHL push don't work" -ForegroundColor Yellow
}

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
  Write-Host "  installed $skillCount skills"

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

  $bbReadme = Join-Path $clinic "Business-Brain\README.md"
  if (-not (Test-Path $bbReadme)) {
    @"
# Business Brain - your foundation lives here

These files are the spine of your whole system. Every skill reads from here.
They get created when you run the foundation skills (do this first):

1. /cc-resonance [clinic]   -> writes resonance-messaging.md
2. /cc-brand-guide [clinic] -> writes brand-guide.md

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
  if ((Get-Command npm -ErrorAction SilentlyContinue) -and (Test-Path $reelSrc)) {
    $reelDest = Join-Path $clinic ".reel-render"
    Copy-Item -Path $reelSrc -Destination $reelDest -Recurse -Force -ErrorAction SilentlyContinue
    Push-Location $reelDest
    npm install *> $null
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
foreach ($c in @('git','node','python','ffmpeg','claude')) {
  if (Get-Command $c -ErrorAction SilentlyContinue) { Write-Host "  ok   $c" } else { Write-Host "  MISSING  $c" -ForegroundColor Yellow; $fail = $true }
}
foreach ($m in @('PIL','requests')) {
  & $py -c "import $m" 2>$null
  if ($LASTEXITCODE -eq 0) { Write-Host "  ok   python:$m" } else { Write-Host "  MISSING  python:$m" -ForegroundColor Yellow; $fail = $true }
}
if (Test-Path (Join-Path $HOME ".claude\skills\cc-content-engine")) { Write-Host "  ok   CC skills installed" } else { Write-Host "  MISSING  CC skills" -ForegroundColor Yellow; $fail = $true }

if (-not $fail) { Say "DONE - everything installed and verified" } else { Say "DONE WITH PROBLEMS - tell your facilitator what is MISSING above" }
Write-Host "Next:  1) close + reopen PowerShell   2) type 'claude' and sign in + paste your API key   3) open ~/Clinic and run /cc-resonance"
Write-Host "One more thing for later (not needed today): /cc-content-engine's social push needs YOUR clinic's own GoHighLevel token."
Write-Host "  Get it from your GHL account (Settings > Private Integrations), then open $HOME\.claude.json and paste it into"
Write-Host "  both BEARER_TOKEN_BEARERAUTH and BEARER_TOKEN_BEARER under mcpServers > gohighlevel > env."
