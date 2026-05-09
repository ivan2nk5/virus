# add_startup_task_win8.ps1
# Run PowerShell as Administrator.
# This script adds setup.bat to Windows Task Scheduler and runs it after every Windows startup.

$ErrorActionPreference = "Stop"

$taskName = "RunProjectSetupOnBoot"
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$batPath = Join-Path $baseDir "setup.bat"
$logPath = Join-Path $baseDir "startup_task_log.txt"

Write-Host "Task name: $taskName"
Write-Host "Base directory: $baseDir"
Write-Host "BAT path: $batPath"
Write-Host "Log path: $logPath"

if (-not (Test-Path $batPath)) {
  Write-Host "ERROR: setup.bat not found at: $batPath"
  exit 1
}

$taskRun = "cmd.exe /c `"cd /d `"$baseDir`" && `"$batPath`" >> `"$logPath`" 2>&1`""

Write-Host "Checking existing task..."

schtasks.exe /Query /TN $taskName *> $null

if ($LASTEXITCODE -eq 0) {
  Write-Host "Existing task found. Deleting old task..."
  schtasks.exe /Delete /TN $taskName /F | Out-Null

  if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: failed to delete old task."
    exit 1
  }
}

Write-Host "Creating startup task..."

schtasks.exe /Create /TN $taskName /SC ONSTART /RU SYSTEM /RL HIGHEST /DELAY 0001:00 /TR $taskRun /F | Out-Null

if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROR: failed to create scheduled task."
  exit 1
}

Write-Host "OK: Task '$taskName' created."
Write-Host "It will run setup.bat after every Windows startup."
Write-Host "Startup log: $logPath"