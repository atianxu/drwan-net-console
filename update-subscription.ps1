param([switch]$Auto, [string]$Root)
# Refresh the node subscription from a list of mirrors, validate, swap atomically,
# restart the core, then pick the fastest node. Safe by default: the previous
# config stays usable if anything fails. Keep this file ASCII-only.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dir = if ($Root) { $Root } else { $PSScriptRoot }
$ctrl = 'http://127.0.0.1:9090'
$log = Join-Path $dir 'update.log'
$meta = Join-Path $dir 'console-meta.json'

function Write-Log([string]$m) {
  $line = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $m
  try { [IO.File]::AppendAllText($log, $line + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))) } catch {}
}

$srcFile = Join-Path $dir 'subscription-sources.txt'
$defaults = @(
  'https://cdn.jsdelivr.net/gh/peasoft/NoMoreWalls@master/list.meta.yml',
  'https://raw.githubusercontent.com/peasoft/NoMoreWalls/master/list.meta.yml',
  'https://ghproxy.net/https://raw.githubusercontent.com/peasoft/NoMoreWalls/master/list.meta.yml',
  'https://gh-proxy.com/https://raw.githubusercontent.com/peasoft/NoMoreWalls/master/list.meta.yml'
)
if (-not (Test-Path -LiteralPath $srcFile)) {
  try { [IO.File]::WriteAllLines($srcFile, $defaults, (New-Object Text.UTF8Encoding($false))) } catch {}
}
$sources = @(Get-Content -LiteralPath $srcFile -Encoding UTF8 -ErrorAction SilentlyContinue |
  Where-Object { $_.Trim() -ne '' -and -not $_.Trim().StartsWith('#') } |
  ForEach-Object { [string]$_.Trim() })
if ($sources.Count -eq 0) { $sources = $defaults }

function Test-Config([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { return 'missing' }
  try {
    $len = (Get-Item -LiteralPath $p).Length
    if ($len -lt 20000) { return 'too small (' + $len + ' bytes)' }
    $hasProxies = $false
    $hasGroups = $false
    $inProxies = $false
    $n = 0
    foreach ($ln in [IO.File]::ReadAllLines($p)) {
      if ($ln.StartsWith('proxies:')) { $hasProxies = $true; $inProxies = $true; continue }
      if ($ln.StartsWith('proxy-groups:')) { $hasGroups = $true; $inProxies = $false; continue }
      if ($inProxies) {
        if ($ln.Length -gt 0 -and -not $ln.StartsWith(' ') -and -not $ln.StartsWith('-')) { $inProxies = $false; continue }
        $tr = $ln.Trim()
        if ($tr.StartsWith('- name:') -or $tr.StartsWith('name:')) { $n++ }
      }
    }
    if (-not $hasProxies) { return 'no proxies block' }
    if (-not $hasGroups) { return 'no proxy-groups block' }
    if ($n -lt 10) { return 'only ' + $n + ' nodes' }
    $exe = Join-Path $dir 'mihomo.exe'
    $outFile = $p + '.test.log'
    $proc = Start-Process -FilePath $exe -ArgumentList @('-t', '-d', $dir, '-f', $p) -RedirectStandardOutput $outFile -RedirectStandardError ($outFile + '.err') -WindowStyle Hidden -PassThru
    $done = $proc.WaitForExit(20000)
    $txt = ''
    try {
      if (Test-Path -LiteralPath $outFile) { $txt += [IO.File]::ReadAllText($outFile) }
      if (Test-Path -LiteralPath ($outFile + '.err')) { $txt += [IO.File]::ReadAllText($outFile + '.err') }
    } catch {}
    Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath ($outFile + '.err') -Force -ErrorAction SilentlyContinue
    if (-not $done) {
      Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
      return 'config test timed out'
    }
    if ($txt -notmatch 'test is successful') {
      $o = ($txt -split [Environment]::NewLine) -join ' '
      if ($o.Length -gt 200) { $o = $o.Substring($o.Length - 200) }
      return 'config test failed: ' + $o.Trim()
    }
    return 'ok:' + $n
  } catch { return 'error: ' + $_.Exception.Message }
}

$cfg = Join-Path $dir 'config.yaml'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$new = Join-Path $dir ('config.' + $stamp + '.new')
$sw = [Diagnostics.Stopwatch]::StartNew()
$picked = $null
$nodeCount = 0

Write-Log ('---- update start (auto=' + [bool]$Auto + ') ----')
$curl = (Get-Command curl.exe -ErrorAction SilentlyContinue)
$proxyUrl = 'http://127.0.0.1:7890'
$routes = @('', $proxyUrl)
foreach ($u in $sources) {
  foreach ($px in $routes) {
    if ($picked) { break }
    if ($sw.Elapsed.TotalSeconds -gt 120) { Write-Log 'budget exhausted, stop trying sources'; break }
    $tag = if ($px) { ' via proxy' } else { ' direct' }
    try {
      Write-Log ('try source:' + $tag + ' ' + $u)
      $ProgressPreference = 'SilentlyContinue'
      if (Test-Path -LiteralPath $new) { Remove-Item -LiteralPath $new -Force -ErrorAction SilentlyContinue }
      if ($curl) {
        $ca = @('-s', '-f', '-L', '-m', '25', '-o', $new)
        if ($px) { $ca += @('-x', $px) }
        $ca += $u
        & $curl.Source @ca
        if ($LASTEXITCODE -ne 0) { throw ('curl exit ' + $LASTEXITCODE) }
      } else {
        if ($px) { Invoke-WebRequest -Uri $u -OutFile $new -TimeoutSec 25 -UseBasicParsing -Proxy $px } else { Invoke-WebRequest -Uri $u -OutFile $new -TimeoutSec 25 -UseBasicParsing }
      }
      $v = Test-Config $new
      if ($v.StartsWith('ok:')) {
        $nodeCount = [int]$v.Substring(3)
        $picked = $u
        Write-Log ('source ok: nodes=' + $nodeCount)
        break
      }
      Write-Log ('source rejected: ' + $v)
      Remove-Item -LiteralPath $new -Force -ErrorAction SilentlyContinue
    } catch {
      Write-Log ('source failed: ' + $_.Exception.Message)
      Remove-Item -LiteralPath $new -Force -ErrorAction SilentlyContinue
    }
  }
  if ($picked) { break }
}

if (-not $picked) {
  Write-Log 'FAIL no usable source; keeping the current config untouched'
  if (Test-Path -LiteralPath $cfg) {
    $still = @(Get-NetTCPConnection -State Listen -LocalPort 7890 -ErrorAction SilentlyContinue)
    if ($still.Count -eq 0) {
      try {
        Start-Process -FilePath (Join-Path $dir 'mihomo.exe') -ArgumentList '-d', $dir -WindowStyle Hidden
        Start-Sleep -Seconds 5
        Write-Log 'core restarted with the existing config'
      } catch { Write-Log ('restart failed: ' + $_.Exception.Message) }
    }
  }
  exit 1
}

try {
  if (Test-Path -LiteralPath $cfg) {
    Copy-Item -LiteralPath $cfg -Destination (Join-Path $dir ('config.bak.' + $stamp + '.yaml')) -Force
    Get-ChildItem -LiteralPath $dir -Filter 'config.bak.*.yaml' | Sort-Object LastWriteTime -Descending |
      Select-Object -Skip 2 | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
  }
  Move-Item -LiteralPath $new -Destination $cfg -Force
  Copy-Item -LiteralPath $cfg -Destination (Join-Path $dir 'sub.meta.yml') -Force -ErrorAction SilentlyContinue
  Write-Log 'config swapped'
} catch {
  Write-Log ('FAIL swap: ' + $_.Exception.Message)
  exit 1
}

# Restart the core and wait for the proxy port.
Stop-Process -Name mihomo -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 1200
Start-Process -FilePath (Join-Path $dir 'mihomo.exe') -ArgumentList '-d', $dir -WindowStyle Hidden
$up = $false
for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Milliseconds 800
  $l = @(Get-NetTCPConnection -State Listen -LocalPort 7890 -ErrorAction SilentlyContinue)
  if ($l.Count -gt 0) { $up = $true; break }
}
if (-not $up) {
  Write-Log 'WARN 7890 not listening after restart'
  $bak = Get-ChildItem -LiteralPath $dir -Filter 'config.bak.*.yaml' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($bak) {
    Copy-Item -LiteralPath $bak.FullName -Destination $cfg -Force
    Stop-Process -Name mihomo -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    Start-Process -FilePath (Join-Path $dir 'mihomo.exe') -ArgumentList '-d', $dir -WindowStyle Hidden
    Start-Sleep -Seconds 6
    Write-Log 'rolled back to the previous config: ' + $bak.Name
  }
  exit 1
}

# Pick the fastest node inside the main selector group.
$groupName = $null
$chosen = $null
try {
  $resp = Invoke-WebRequest -Uri ($ctrl + '/proxies') -TimeoutSec 6 -UseBasicParsing
  $j = ([Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())) | ConvertFrom-Json
  $props = $j.proxies.PSObject.Properties
  $ut = $null
  $utCnt = -1
  foreach ($p in $props) {
    if ($p.Value.type -eq 'URLTest') {
      $c = @($p.Value.all).Count
      if ($c -gt $utCnt) { $utCnt = $c; $ut = $p.Name }
    }
  }
  if ($ut) {
    foreach ($p in $props) {
      if ($p.Value.type -eq 'Selector' -and $p.Name -ne 'GLOBAL' -and (@($p.Value.all) -contains $ut)) { $groupName = $p.Name; break }
    }
  }
  if ($ut -and $groupName) {
    $body = '{"name":"' + ($ut -replace '"', '') + '"}'
    Invoke-WebRequest -Uri ($ctrl + '/proxies/' + [uri]::EscapeDataString($groupName)) -Method Put -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json' -TimeoutSec 8 -UseBasicParsing | Out-Null
    $chosen = $ut
    Write-Log ('selector set to auto group: ' + $groupName + ' -> ' + $ut + ' (' + $utCnt + ' nodes)')
  } elseif ($ut) {
    Write-Log ('auto group ' + $ut + ' (' + $utCnt + ' nodes) is not wired to any selector; left as is')
    $chosen = $ut
  } else { Write-Log 'no auto (URLTest) group found; keeping the default selection' }
} catch { Write-Log ('node picking skipped: ' + $_.Exception.Message) }

$rec = @{ lastUpdate = (Get-Date).ToString('o'); source = [string]$picked; nodeCount = $nodeCount; group = $groupName; node = $chosen } | ConvertTo-Json -Compress
try { [IO.File]::WriteAllText($meta, $rec, (New-Object Text.UTF8Encoding($false))) } catch {}
Write-Log ('---- update done in ' + [int]$sw.Elapsed.TotalSeconds + 's, nodes=' + $nodeCount + ' ----')
exit 0
