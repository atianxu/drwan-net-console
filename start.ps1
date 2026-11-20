# Start mihomo, verify the listening ports, show a balloon notification in the
# lower-right corner, and write a status file. No external modules required:
# the notification uses the built-in System.Windows.Forms NotifyIcon.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $dir 'mihomo.exe'
$statusFile = Join-Path $dir 'status.txt'
$proxy = 'http://127.0.0.1:7890'

function Show-Balloon([string]$title, [string]$message, [string]$kind) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $ni = New-Object System.Windows.Forms.NotifyIcon
  $ni.Icon = [System.Drawing.SystemIcons]::Information
  if ($kind -eq 'error') { $ni.Icon = [System.Drawing.SystemIcons]::Error }
  $ni.BalloonTipTitle = $title
  $ni.BalloonTipText = $message
  $ni.Visible = $true
  $ni.ShowBalloonTip(8000)
  Start-Sleep -Seconds 9
  $ni.Dispose()
}

$running = Get-Process -Name mihomo -ErrorAction SilentlyContinue
if ($running) {
  $msg = 'mihomo already running. Proxy 127.0.0.1:7890, controller 9090.'
  "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  already running" | Out-File $statusFile
  Show-Balloon 'Proxy already running' $msg 'info'
  Write-Host $msg
  return
}

try {
  Start-Process -FilePath $exe -ArgumentList '-d', $dir -WindowStyle Hidden
  # Wait for the mixed-port to come up (up to ~15s).
  $ok = $false
  for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    $conn = Get-NetTCPConnection -LocalPort 7890 -State Listen -ErrorAction SilentlyContinue
    if ($conn) { $ok = $true; break }
  }
  if (-not $ok) { throw 'mixed-port 7890 did not start listening within 15s' }

  $controller = Get-NetTCPConnection -LocalPort 9090 -State Listen -ErrorAction SilentlyContinue
  $ctrlText = if ($controller) { 'controller 9090 up' } else { 'controller 9090 not detected' }

  # Quick reachability check through the proxy.
  $netOk = $false
  try {
    $r = Invoke-WebRequest -Uri 'https://api.github.com/rate_limit' -Proxy $proxy `
      -UseBasicParsing -TimeoutSec 15
    $netOk = ($r.StatusCode -eq 200)
  } catch { $netOk = $false }

  $netText = if ($netOk) { 'GitHub reachable through proxy' } else { 'proxy listening; GitHub check failed' }
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  running; $ctrlText; $netText"
  $line | Out-File $statusFile
  Write-Host "mihomo started. Proxy 127.0.0.1:7890. $ctrlText. $netText."
  Show-Balloon 'Proxy started' "mihomo is running.`n$ctrlText`n$netText." 'info'
} catch {
  "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  ERROR: $($_.Exception.Message)" | Out-File $statusFile
  Write-Host ("Failed to start: " + $_.Exception.Message)
  Show-Balloon 'Proxy failed to start' $_.Exception.Message 'error'
  exit 1
}
