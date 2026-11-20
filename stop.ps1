# Stop mihomo and confirm with a balloon notification.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusFile = Join-Path $dir 'status.txt'

function Show-Balloon([string]$title, [string]$message, [string]$kind) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $ni = New-Object System.Windows.Forms.NotifyIcon
  $ni.Icon = [System.Drawing.SystemIcons]::Warning
  if ($kind -eq 'info') { $ni.Icon = [System.Drawing.SystemIcons]::Information }
  $ni.BalloonTipTitle = $title
  $ni.BalloonTipText = $message
  $ni.Visible = $true
  $ni.ShowBalloonTip(8000)
  Start-Sleep -Seconds 9
  $ni.Dispose()
}

$proc = Get-Process -Name mihomo -ErrorAction SilentlyContinue
if (-not $proc) {
  "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  stopped (was not running)" | Out-File $statusFile
  Write-Host 'mihomo was not running.'
  Show-Balloon 'Proxy not running' 'No mihomo process was found.' 'info'
  return
}

Stop-Process -Name mihomo -Force
Start-Sleep -Seconds 1
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  stopped" | Out-File $statusFile
Write-Host 'mihomo stopped.'
Show-Balloon 'Proxy stopped' 'mihomo has been stopped.' 'info'
