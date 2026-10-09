# Clinic Catalyst - UPDATE your skills for Codex (Windows).
# Usage (PowerShell):  irm https://clinic-catalyst-au.github.io/cc-onboard/clinic-codex-update.ps1 | iex
# Downloads the latest skill pack and refreshes ~\.agents\skills. Your Clinic folder, Business Brain
# and AGENTS.md are left alone (AGENTS.md is only created if missing). Body = the Codex-written,
# verified skills block from install-codex.html step 7.
Write-Host "`nUpdating your Clinic Catalyst skills for Codex..." -ForegroundColor Cyan
& {
  $ErrorActionPreference = 'Stop'
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $workDir = Join-Path $env:TEMP ('cc-clinic-pack-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $workDir -Force | Out-Null
  $zipPath = Join-Path $workDir 'cc-clinic-pack.zip'
  $extractDir = Join-Path $workDir 'extracted'
  Invoke-WebRequest -UseBasicParsing -Uri 'https://clinic-catalyst-au.github.io/cc-onboard/cc-clinic-pack.zip' -OutFile $zipPath
  Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
  $packDir = Join-Path $extractDir 'cc-clinic-pack'
  $sourceSkills = Join-Path $packDir 'skills'
  $template = Join-Path $packDir 'templates\clinic-CLAUDE.md'
  if (-not (Test-Path -LiteralPath $sourceSkills -PathType Container)) { throw 'The ZIP is missing cc-clinic-pack\skills.' }
  if (-not (Test-Path -LiteralPath $template -PathType Leaf)) { throw 'The ZIP is missing templates\clinic-CLAUDE.md.' }
  $skillsDir = Join-Path $HOME '.agents\skills'
  New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
  Copy-Item -Path (Join-Path $sourceSkills '*') -Destination $skillsDir -Recurse -Force
  $clinicDir = Join-Path $HOME 'Clinic'
  foreach ($folder in @('Business-Brain\brand-assets', 'Content', 'Emails', 'Ads')) {
    New-Item -ItemType Directory -Path (Join-Path $clinicDir $folder) -Force | Out-Null
  }
  $agentsFile = Join-Path $clinicDir 'AGENTS.md'
  if (-not (Test-Path -LiteralPath $agentsFile)) {
    Copy-Item -LiteralPath $template -Destination $agentsFile
  }
  Write-Host 'Clinic Catalyst skills and clinic folders are installed.'
}
$n = @(Get-ChildItem -LiteralPath (Join-Path $HOME '.agents\skills') -Directory -Filter 'cc-*' -ErrorAction SilentlyContinue).Count
Write-Host "`nDONE - $n Clinic Catalyst skills up to date." -ForegroundColor Cyan
Write-Host "Next: close Codex if it is open, then start it again:  cd ~\Clinic; codex.cmd"
