# Clinic Catalyst - UPDATE (Windows). One command to pull the latest skills onto this machine.
# Re-downloads the live clinic pack and MERGES the skills into %USERPROFILE%\.claude\skills
# (non-destructive: updates CC skills, adds new ones, never touches your Business Brain or other skills).
# Clinics install from the pack zip (no git repo), so this is the right update path for them.
$ErrorActionPreference = "Stop"
Write-Host ""
Write-Host "Clinic Catalyst update - fetching the latest skills" -ForegroundColor Cyan
Set-Location $HOME\Downloads
try {
  Invoke-RestMethod "https://clinic-catalyst-au.github.io/cc-onboard/cc-clinic-pack.zip" -OutFile ccpack-update.zip
  if (Test-Path ccpack-update) { Remove-Item -Recurse -Force ccpack-update }
  Expand-Archive -Force ccpack-update.zip ccpack-update
  $dest = "$env:USERPROFILE\.claude\skills"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item -Recurse -Force ccpack-update\cc-clinic-pack\skills\* $dest\
  $n = (Get-ChildItem $dest -Directory | Where-Object { $_.Name -like 'cc-*' }).Count
  Remove-Item -Force ccpack-update.zip
  Remove-Item -Recurse -Force ccpack-update
  Write-Host "  updated - $n CC skills now installed"
  Write-Host ""
  Write-Host "DONE. Now CLOSE and REOPEN Claude Code (and PowerShell) so the new skills register:"
  Write-Host "  /cc-nurture-sequence  /cc-thankyou-page  /cc-fb-leadform"
  Write-Host "Your Business Brain and your own work were NOT touched - this only refreshes the skills."
} catch {
  Write-Host "  !! could not download the pack - check your internet, then re-run this command." -ForegroundColor Red
}
