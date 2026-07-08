# Clinic Catalyst - TURN ON AUTO-UPDATE (Windows). Run this ONCE per machine.
# Registers a Scheduled Task that refreshes the CC skills automatically - once right
# now, then daily and at every logon - so nobody runs an update command again.
# Non-destructive: only refreshes CC skills, never touches the Business Brain.
$ErrorActionPreference = "Stop"
$taskName  = "ClinicCatalystAutoUpdate"
$updateUrl = "https://clinic-catalyst-au.github.io/cc-onboard/clinic-update.ps1"
$inner     = "try { irm $updateUrl | iex } catch {}"
$encoded   = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inner))

$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -WindowStyle Hidden -EncodedCommand $encoded"
$daily   = New-ScheduledTaskTrigger -Daily -At 7:30am
$logon   = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $daily,$logon `
  -Settings $settings -Force -Description "Clinic Catalyst auto-update of CC skills" | Out-Null

Write-Host ""
Write-Host "Auto-update is ON." -ForegroundColor Cyan
Write-Host "  - Runs the skill refresh automatically every day (7:30am) and at logon"
Write-Host "  - No one needs to run an update command again on this machine"
Write-Host ""
Write-Host "Running it once now..."
try { irm $updateUrl | iex } catch { Write-Host "  (first run will happen at next logon)" -ForegroundColor Yellow }
Write-Host ""
Write-Host "Last step: CLOSE and REOPEN Claude Code (and PowerShell) so the refreshed skills register."
