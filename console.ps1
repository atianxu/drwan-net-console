# Integrated mihomo control console (WPF), Chinese UI.
# This file must be UTF-8 with BOM.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $dir 'mihomo.exe'
$iconPath = Join-Path $dir 'tray.ico'
$traceLog = Join-Path $dir 'console-trace.log'
$metaPath = Join-Path $dir 'console-meta.json'
$statePath = Join-Path $dir 'console-state.json'
$ctrl = 'http://127.0.0.1:9090'
$proxy = 'http://127.0.0.1:7890'
$regKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$taskAuto = 'mihomo-autostart'
$taskUpdate = 'mihomo-subupdate'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Trace-Log([string]$m) {
  try {
    $line = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') + '  ' + $m
    [IO.File]::AppendAllText($traceLog, $line + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
  } catch {}
}
Trace-Log ('===== console starting (pid=' + $PID + ') =====')

if (-not ('WinInetRefresh' -as [type])) {
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WinInetRefresh {
  [DllImport("wininet.dll", SetLastError=true)]
  private static extern bool InternetSetOption(IntPtr h, int option, IntPtr buf, int len);
  public static void Apply() {
    InternetSetOption(IntPtr.Zero, 39, IntPtr.Zero, 0);
    InternetSetOption(IntPtr.Zero, 37, IntPtr.Zero, 0);
  }
}
'@
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Title="科学上网控制台" Width="460" SizeToContent="Height"
  WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
  Background="#F4F6FB" FontFamily="Microsoft YaHei UI">
  <StackPanel Margin="20">
    <Grid Margin="0,0,0,12">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0" Orientation="Horizontal" Height="30">
        <Ellipse x:Name="KernelDot" Width="10" Height="10" Fill="#E0504D" VerticalAlignment="Center" Margin="0,0,8,0"/>
        <TextBlock x:Name="KernelText" Text="内核 检查中" FontSize="14" FontWeight="SemiBold" Foreground="#222831" VerticalAlignment="Center"/>
      </StackPanel>
      <StackPanel Grid.Column="2" Orientation="Horizontal" Height="30">
        <Ellipse x:Name="SysProxyDot" Width="10" Height="10" Fill="#9AA3B2" VerticalAlignment="Center" Margin="0,0,8,0"/>
        <TextBlock x:Name="SysProxyText" Text="系统代理 未知" FontSize="14" FontWeight="SemiBold" Foreground="#222831" VerticalAlignment="Center"/>
      </StackPanel>
    </Grid>

    <Border Background="White" CornerRadius="10" Padding="14" Margin="0,0,0,12">
      <StackPanel>
        <ToggleButton x:Name="ProxyToggle" Height="42" FontSize="15" Foreground="White"
          Background="#3B82F6" BorderThickness="0" Content="系统代理：已关闭"/>
        <TextBlock x:Name="ProxyHint" Text="浏览器和应用走 127.0.0.1:7890" FontSize="12"
          Foreground="#7A8290" Margin="0,8,0,0"/>
      </StackPanel>
    </Border>

    <Border Background="White" CornerRadius="10" Padding="14" Margin="0,0,0,12">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="1*"/><ColumnDefinition Width="1*"/><ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
          <RowDefinition Height="26"/><RowDefinition Height="26"/><RowDefinition Height="26"/>
        </Grid.RowDefinitions>
        <TextBlock x:Name="NodeName" Grid.Row="0" Grid.ColumnSpan="3" Text="节点 —" FontSize="14"
          Foreground="#222831" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
        <TextBlock x:Name="LatencyText" Grid.Row="1" Grid.Column="0" Text="延迟 —" FontSize="14"
          Foreground="#222831" VerticalAlignment="Center"/>
        <TextBlock x:Name="NodeCountText" Grid.Row="1" Grid.Column="1" Text="节点数 —" FontSize="14"
          Foreground="#222831" VerticalAlignment="Center"/>
        <Button x:Name="SpeedBtn" Grid.Row="1" Grid.Column="2" Content="测速" Height="24"
          Padding="8,0" FontSize="12" Background="White" BorderBrush="#D6DBE5" Foreground="#222831"/>
        <TextBlock x:Name="SubAgeText" Grid.Row="2" Grid.Column="0" Text="订阅 —" FontSize="14"
          Foreground="#222831" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
        <TextBlock x:Name="PortText" Grid.Row="2" Grid.Column="1" Grid.ColumnSpan="2"
          Text="端口 7890 / 9090" FontSize="14" Foreground="#222831" VerticalAlignment="Center"/>
      </Grid>
    </Border>

    <Button x:Name="KernelBtn" Height="36" Content="启动内核" Background="White"
      Foreground="#222831" BorderBrush="#D6DBE5"/>
    <TextBlock x:Name="KernelHint" Text="内核未启动时系统代理不可用" FontSize="12"
      Foreground="#7A8290" Margin="2,6,0,12"/>

    <Border Background="White" CornerRadius="10" Padding="14" Margin="0,0,0,12">
      <StackPanel>
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <CheckBox x:Name="AutoChk" Grid.Column="0" Content="自动更新订阅" Foreground="#222831" VerticalAlignment="Center"/>
          <ComboBox x:Name="AutoPolicy" Grid.Column="1" Width="120" Height="26">
            <ComboBoxItem Content="每天"/>
            <ComboBoxItem Content="每次启动时"/>
            <ComboBoxItem Content="只手动"/>
          </ComboBox>
        </Grid>
        <Grid Margin="0,8,0,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock x:Name="UpdateResult" Grid.Column="0" Text="上次：—" FontSize="12"
            Foreground="#7A8290" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
          <Button x:Name="UpdateNow" Grid.Column="1" Content="立即更新" Height="26" Padding="10,0"
            FontSize="12" Background="White" Foreground="#222831" BorderBrush="#D6DBE5"/>
        </Grid>
        <ProgressBar x:Name="UpdateBar" Height="3" IsIndeterminate="True" Visibility="Collapsed" Margin="0,8,0,0"/>
      </StackPanel>
    </Border>

    <CheckBox x:Name="AutoStart" Content="登录系统时自动启动内核" Foreground="#222831" Margin="2,0,0,10"/>
    <Expander x:Name="LogExp" Header="运行日志" Foreground="#7A8290" FontSize="12">
      <Border Background="#1E2530" CornerRadius="8" Padding="10" Margin="0,6,0,0">
        <TextBox x:Name="Log" Height="96" IsReadOnly="True" Background="Transparent"
          Foreground="#CFE3FF" BorderThickness="0" FontFamily="Consolas" FontSize="12"
          TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
      </Border>
    </Expander>
  </StackPanel>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [System.Windows.Markup.XamlReader]::Load($reader)
function C($n) { $win.FindName($n) }
$kernelDot = C 'KernelDot'; $kernelText = C 'KernelText'
$sysDot = C 'SysProxyDot'; $sysText = C 'SysProxyText'
$proxyToggle = C 'ProxyToggle'; $proxyHint = C 'ProxyHint'
$nodeName = C 'NodeName'; $latencyText = C 'LatencyText'; $nodeCountText = C 'NodeCountText'
$speedBtn = C 'SpeedBtn'; $subAgeText = C 'SubAgeText'; $portText = C 'PortText'
$kernelBtn = C 'KernelBtn'; $kernelHint = C 'KernelHint'
$autoChk = C 'AutoChk'; $autoPolicy = C 'AutoPolicy'
$updateResult = C 'UpdateResult'; $updateNow = C 'UpdateNow'; $updateBar = C 'UpdateBar'
$autoStart = C 'AutoStart'; $logBox = C 'Log'

$script:winGdiIcon = $null
if (Test-Path $iconPath) {
  $script:winGdiIcon = New-Object System.Drawing.Icon $iconPath
  $win.Icon = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
    $script:winGdiIcon.Handle, [System.Windows.Int32Rect]::Empty,
    [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
}

function Write-Log([string]$m) {
  $ts = Get-Date -Format 'HH:mm:ss'
  try { $logBox.AppendText('[' + $ts + '] ' + $m + [Environment]::NewLine); $logBox.ScrollToEnd() } catch {}
  Trace-Log ('ui: ' + $m)
}

# --- state file ---------------------------------------------------------------
function Read-State {
  $s = @{}
  if (Test-Path -LiteralPath $statePath) {
    try {
      $o = (Get-Content -LiteralPath $statePath -Raw -Encoding UTF8) | ConvertFrom-Json
      foreach ($p in $o.PSObject.Properties) { $s[$p.Name] = $p.Value }
    } catch {}
  }
  return $s
}
function Write-State($s) {
  try {
    $o = [ordered]@{}
    foreach ($k in $s.Keys) { $o[$k] = $s[$k] }
    [IO.File]::WriteAllText($statePath, ($o | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
  } catch {}
}

# --- probes -------------------------------------------------------------------
function Test-Kernel {
  $c = New-Object Net.Sockets.TcpClient
  try {
    $ar = $c.BeginConnect('127.0.0.1', 9090, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne(300)) { return $false }
    $c.EndConnect($ar)
    return $c.Connected
  } catch { return $false } finally { try { $c.Close() } catch {} }
}
function Test-SysProxy {
  try { $v = Get-ItemProperty -Path $regKey -ErrorAction Stop; return [bool]$v.ProxyEnable } catch { return $false }
}
function Get-CtrlJson([string]$path) {
  $resp = Invoke-WebRequest -Uri ($ctrl + $path) -TimeoutSec 4 -UseBasicParsing
  $bytes = $resp.RawContentStream.ToArray()
  $txt = [Text.Encoding]::UTF8.GetString($bytes)
  return ($txt | ConvertFrom-Json)
}
function Find-ProxyGroup($j) {
  $pref = @('选择代理', '手动选择', 'Proxy', 'Select')
  foreach ($want in $pref) {
    foreach ($p in $j.proxies.PSObject.Properties) {
      if ($p.Value.type -eq 'Selector' -and $p.Name -like ('*' + $want + '*')) { return $p }
    }
  }
  return $null
}

# --- system proxy -------------------------------------------------------------
function Enable-SysProxy {
  $st = Read-State
  if (-not $st.ContainsKey('sysProxySnapshot') -or -not $st['sysProxySnapshot']) {
    $v = Get-ItemProperty -Path $regKey
    $st['sysProxySnapshot'] = @{ enable = [int]$v.ProxyEnable; server = [string]$v.ProxyServer; override = [string]$v.ProxyOverride }
    Write-State $st
  }
  Set-ItemProperty -Path $regKey -Name ProxyEnable -Value 1
  Set-ItemProperty -Path $regKey -Name ProxyServer -Value '127.0.0.1:7890'
  Set-ItemProperty -Path $regKey -Name ProxyOverride -Value '127.0.0.1;localhost;<local>'
  [WinInetRefresh]::Apply()
}
function Disable-SysProxy {
  $st = Read-State
  if ($st.ContainsKey('sysProxySnapshot') -and $st['sysProxySnapshot']) {
    $snap = $st['sysProxySnapshot']
    Set-ItemProperty -Path $regKey -Name ProxyServer -Value ([string]$snap.server)
    Set-ItemProperty -Path $regKey -Name ProxyOverride -Value ([string]$snap.override)
    Set-ItemProperty -Path $regKey -Name ProxyEnable -Value ([int]$snap.enable)
    $st['sysProxySnapshot'] = $null
    Write-State $st
  } else {
    Set-ItemProperty -Path $regKey -Name ProxyEnable -Value 0
  }
  [WinInetRefresh]::Apply()
}

# --- kernel -------------------------------------------------------------------
function Start-Kernel {
  if (Test-Kernel) { return $true }
  $st = Read-State
  $st['sysProxyAutoOff'] = $null
  Write-State $st
  Start-Process -FilePath $exe -ArgumentList '-d', $dir -WindowStyle Hidden
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 600
    if (Test-Kernel) { return $true }
  }
  return $false
}
function Stop-Kernel {
  Stop-Process -Name mihomo -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 800
  return (-not (Test-Kernel))
}

# --- ui refresh ---------------------------------------------------------------
function Refresh-Fast {
  $k = Test-Kernel
  if ($k) {
    $kernelDot.Fill = '#22C55E'; $kernelText.Text = '内核 运行中'
    $kernelBtn.Content = '停止内核'; $kernelBtn.Foreground = '#E0504D'
  } else {
    $kernelDot.Fill = '#E0504D'; $kernelText.Text = '内核 已停止'
    $kernelBtn.Content = '启动内核'; $kernelBtn.Foreground = '#222831'
  }
  $p = Test-SysProxy
  if ($p) {
    $sysDot.Fill = '#22C55E'; $sysText.Text = '系统代理 开'
    $proxyToggle.IsChecked = $true; $proxyToggle.Content = '系统代理：已开启'
    $proxyToggle.Background = '#22C55E'
  } else {
    $sysDot.Fill = '#9AA3B2'; $sysText.Text = '系统代理 关'
    $proxyToggle.IsChecked = $false; $proxyToggle.Content = '系统代理：已关闭'
    $proxyToggle.Background = '#3B82F6'
  }
  if (-not $k) {
    $proxyToggle.IsEnabled = $false
    $proxyHint.Text = '内核未启动，系统代理不可用（先启动内核）'
    $speedBtn.IsEnabled = $false
  } else {
    $proxyToggle.IsEnabled = $true
    $proxyHint.Text = '浏览器和应用走 127.0.0.1:7890'
    $speedBtn.IsEnabled = $true
  }
}
function Refresh-Slow {
  if (Test-Kernel) {
    try {
      $j = Get-CtrlJson '/proxies'
      $g = Find-ProxyGroup $j
      if ($g) {
        $now = [string]$g.Value.now
        $nodeName.Text = '节点 ' + $now
        $nodeName.ToolTip = $now
        $nodeCountText.Text = '节点数 ' + $g.Value.all.Count
      } else {
        $nodeName.Text = '节点 —'; $nodeCountText.Text = '节点数 —'
      }
    } catch {
      Trace-Log ('slow refresh error: ' + $_.Exception.Message)
      $nodeName.Text = '节点 —'; $nodeCountText.Text = '节点数 —'
    }
  } else {
    $nodeName.Text = '节点 —'; $nodeName.ToolTip = ''; $nodeCountText.Text = '节点数 —'; $latencyText.Text = '延迟 —'
  }
  if (Test-Path -LiteralPath $metaPath) {
    try {
      $m = (Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8) | ConvertFrom-Json
      $t = [datetime]$m.lastUpdate
      $age = (Get-Date) - $t
      if ($age.TotalHours -lt 1) { $a = [int][math]::Max(1, $age.TotalMinutes) ; $subAgeText.Text = '订阅 ' + $a + ' 分钟前' }
      elseif ($age.TotalDays -lt 1) { $subAgeText.Text = '订阅 ' + [int]$age.TotalHours + ' 小时前' }
      elseif ($age.TotalDays -lt 8) { $subAgeText.Text = '订阅 ' + [int]$age.TotalDays + ' 天前' }
      else { $subAgeText.Text = '订阅 ' + $t.ToString('MM-dd') }
      $subAgeText.ToolTip = '上次成功更新：' + $t.ToString('yyyy-MM-dd HH:mm')
      if ($m.nodeCount) { $nodeCountText.Text = '节点数 ' + $m.nodeCount }
      $src = if ($m.node -and $m.group) { '成功 · 当前 ' + [string]$m.node } else { '成功' }
      $updateResult.Text = '上次：' + $src
      $updateResult.Foreground = '#7A8290'
    } catch {}
  } else {
    $subAgeText.Text = '订阅 未更新过'
  }
}

# --- speed test ---------------------------------------------------------------
function Measure-Node {
  if (-not (Test-Kernel)) { $latencyText.Text = '延迟 —'; return }
  $latencyText.Text = '延迟 测试中'
  try {
    $j = Get-CtrlJson '/proxies'
    $g = Find-ProxyGroup $j
    if (-not $g) { $latencyText.Text = '延迟 —'; return }
    $name = [string]$g.Value.now
    $u = $ctrl + '/proxies/' + [uri]::EscapeDataString($name) + '/delay?url=' + [uri]::EscapeDataString('https://www.gstatic.com/generate_204') + '&timeout=3000'
    $d = ((Invoke-WebRequest -Uri $u -TimeoutSec 6 -UseBasicParsing).Content | ConvertFrom-Json)
    if ($d.delay -and $d.delay -gt 0) { $latencyText.Text = '延迟 ' + $d.delay + ' ms' }
    else { $latencyText.Text = '延迟 不通' }
  } catch { Trace-Log ('measure error: ' + $_.Exception.Message); $latencyText.Text = '延迟 不通' }
}

# --- auto update --------------------------------------------------------------
$script:updProc = $null
function Start-Updater {
  if ($script:updProc -and -not $script:updProc.HasExited) { Write-Log '更新仍在进行，稍等。'; return }
  $upd = Join-Path $dir 'update-subscription.ps1'
  if (-not (Test-Path -LiteralPath $upd)) { Write-Log '缺少 update-subscription.ps1，无法更新。'; return }
  $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $script:updProc = Start-Process -FilePath $psExe -WindowStyle Hidden -PassThru -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $upd + '"'), '-Auto', '-Root', ('"' + $dir + '"')
  )
  $updateBar.Visibility = 'Visible'
  $updateNow.IsEnabled = $false
  $updateNow.Content = '更新中…'
  $updateResult.Text = '正在下载新订阅…'
  $updateResult.Foreground = '#F59E0B'
  Write-Log '已开始更新订阅（后台运行，窗口不会卡）。'
}
function Poll-Updater {
  if (-not $script:updProc) { return }
  if (-not $script:updProc.HasExited) { return }
  $code = $script:updProc.ExitCode
  $script:updProc = $null
  $updateBar.Visibility = 'Collapsed'
  $updateNow.IsEnabled = $true
  $updateNow.Content = '立即更新'
  if ($code -eq 0) {
    $updateResult.Text = '上次：成功'
    $updateResult.Foreground = '#22C55E'
    Write-Log '订阅更新成功，内核已重启，节点已切换。'
  } else {
    $updateResult.Text = '上次：失败（已保留旧配置）'
    $updateResult.Foreground = '#E0504D'
    Write-Log '订阅更新失败，请展开日志看 update.log 详情。'
  }
  Refresh-Slow
}

function Update-AutoTask {
  $mode = 'none'
  if ($autoChk.IsChecked) { $mode = if ($autoPolicy.SelectedIndex -eq 0) { 'daily' } elseif ($autoPolicy.SelectedIndex -eq 1) { 'startup' } else { 'none' } }
  $st = Read-State
  $st['autoChk'] = [bool]$autoChk.IsChecked
  $st['autoPolicy'] = $mode
  Write-State $st
  try {
    Unregister-ScheduledTask -TaskName $taskUpdate -Confirm:$false -ErrorAction SilentlyContinue
    if ($mode -eq 'daily') {
      $upd = Join-Path $dir 'update-subscription.ps1'
      $arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $upd + '" -Auto -Root "' + $dir + '"'
      $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
      $trg = New-ScheduledTaskTrigger -Daily -At '04:00'
      Register-ScheduledTask -TaskName $taskUpdate -Action $act -Trigger $trg -Force | Out-Null
      Write-Log '已设置每天 04:00 自动更新订阅。'
    } elseif ($mode -eq 'startup') { Write-Log '已设置：每次启动控制台时检查并更新订阅。' }
    else { Write-Log '已关闭自动更新订阅。' }
  } catch { Write-Log ('设置自动更新失败：' + $_.Exception.Message) }
}

# --- tray ---------------------------------------------------------------------
$script:reallyExit = $false
$script:suppressHide = $false
$tray = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path $iconPath) { $tray.Icon = New-Object System.Drawing.Icon $iconPath }
else { $tray.Icon = [System.Drawing.SystemIcons]::Application }
$tray.Text = '科学上网控制台'
$tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$mState = $menu.Items.Add('状态读取中…'); $mState.Enabled = $false
$mSysOn = $menu.Items.Add('打开系统代理')
$mSysOff = $menu.Items.Add('关闭系统代理')
$mSep1 = $menu.Items.Add('-')
$mKStart = $menu.Items.Add('启动内核')
$mKStop = $menu.Items.Add('停止内核')
$mUpdate = $menu.Items.Add('更新订阅')
$mSep2 = $menu.Items.Add('-')
$mShow = $menu.Items.Add('显示控制台')
$mExit = $menu.Items.Add('退出程序')

function Invoke-Safe([scriptblock]$body) {
  try { & $body }
  catch {
    Trace-Log ('handler error: ' + $_.Exception.Message + ' | ' + $_.InvocationInfo.PositionMessage)
    try { Write-Log ('内部错误（已捕获）：' + $_.Exception.Message) } catch {}
  }
}
function Update-TrayText {
  $k = if (Test-Kernel) { '运行中' } else { '已停止' }
  $p = if (Test-SysProxy) { '开' } else { '关' }
  $mState.Text = '内核：' + $k + ' · 系统代理：' + $p
  $mSysOn.Enabled = ($k -eq '运行中')
  $mSysOff.Enabled = ($p -eq '开')
  $mKStart.Enabled = ($k -ne '运行中')
  $mKStop.Enabled = ($k -eq '运行中')
}
function Show-Window {
  $script:suppressHide = $true
  $win.Show()
  $win.WindowState = [System.Windows.WindowState]::Normal
  [void]$win.Activate()
  $script:suppressHide = $false
  Refresh-Fast
  Refresh-Slow
}
function Hide-ToTray([string]$note) {
  $win.Hide()
  if ($note) {
    $tray.BalloonTipTitle = '科学上网控制台'
    $tray.BalloonTipText = $note
    $tray.ShowBalloonTip(3000)
  }
}

$tray.Add_MouseDoubleClick({ Invoke-Safe {
  if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-Window }
} })
$tray.Add_MouseClick({ Invoke-Safe {
  if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-Window }
} })
$mShow.Add_Click({ Invoke-Safe { Show-Window } })
$mExit.Add_Click({ Invoke-Safe {
  $script:reallyExit = $true
  $tray.Visible = $false
  $tray.Dispose()
  $win.Close()
  [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
} })
$mSysOn.Add_Click({ Invoke-Safe {
  if (-not (Test-Kernel)) { Write-Log '请先启动内核。'; return }
  Enable-SysProxy; Write-Log '系统代理已打开（127.0.0.1:7890）。'; Refresh-Fast
} })
$mSysOff.Add_Click({ Invoke-Safe {
  Disable-SysProxy; Write-Log '系统代理已关闭，恢复原设置。'; Refresh-Fast
} })
$mKStart.Add_Click({ Invoke-Safe {
  Write-Log '正在启动内核…'
  if (Start-Kernel) { Write-Log '内核已启动，7890 正在监听。' } else { Write-Log '内核启动失败：7890 未就绪。' }
  Refresh-Fast; Refresh-Slow
} })
$mKStop.Add_Click({ Invoke-Safe {
  Write-Log '正在停止内核…'
  $st = Read-State
  if (Test-SysProxy) { Disable-SysProxy; Write-Log '系统代理已随内核一起关闭。' }
  if (Stop-Kernel) { Write-Log '内核已停止。' } else { Write-Log '内核停止失败，请稍后再试。' }
  Refresh-Fast; Refresh-Slow
} })
$mUpdate.Add_Click({ Invoke-Safe { Start-Updater } })

$win.Add_StateChanged({ Invoke-Safe {
  if (($win.WindowState -eq [System.Windows.WindowState]::Minimized) -and (-not $script:suppressHide)) {
    Hide-ToTray '已最小化到托盘，左键单击图标可恢复。'
  }
} })
$win.Add_Closing({ Invoke-Safe {
  if (-not $script:reallyExit) {
    $_.Cancel = $true
    Hide-ToTray '程序仍在后台运行，可从托盘退出。'
  }
} })

# --- button handlers ----------------------------------------------------------
$proxyToggle.Add_Click({ Invoke-Safe {
  $proxyToggle.IsEnabled = $false
  $proxyHint.Text = '切换中…'
  try {
    if (Test-SysProxy) {
      Disable-SysProxy; Write-Log '系统代理已关闭，恢复原设置。'
    } else {
      if (-not (Test-Kernel)) {
        Write-Log '内核未运行，先启动内核。'
        if (-not (Start-Kernel)) { Write-Log '内核启动失败，系统代理保持关闭。'; return }
      }
      Enable-SysProxy; Write-Log '系统代理已打开（127.0.0.1:7890）。'
    }
  } finally {
    Refresh-Fast
    $proxyToggle.IsEnabled = $true
  }
} })
$kernelBtn.Add_Click({ Invoke-Safe {
  $kernelBtn.IsEnabled = $false
  try {
    if (Test-Kernel) {
      if (Test-SysProxy) { Disable-SysProxy; Write-Log '系统代理已随内核一起关闭。' }
      Write-Log '正在停止内核…'
      if (Stop-Kernel) { Write-Log '内核已停止。' } else { Write-Log '内核停止失败。' }
    } else {
      Write-Log '正在启动内核…'
      if (Start-Kernel) { Write-Log '内核已启动，7890 正在监听。' } else { Write-Log '内核启动失败：7890 未就绪。' }
    }
  } finally {
    $kernelBtn.IsEnabled = $true
    Refresh-Fast; Refresh-Slow
  }
} })
$speedBtn.Add_Click({ Invoke-Safe { Measure-Node } })
$updateNow.Add_Click({ Invoke-Safe { Start-Updater } })
$autoChk.Add_Click({ Invoke-Safe { Update-AutoTask } })
$autoPolicy.Add_SelectionChanged({ Invoke-Safe {
  $autoPolicy.IsEnabled = [bool]$autoChk.IsChecked
  if ($autoChk.IsChecked) { Update-AutoTask }
} })
$autoStart.Add_Click({ Invoke-Safe {
  if ($autoStart.IsChecked) {
    $a = New-ScheduledTaskAction -Execute $exe -Argument ('-d "' + $dir + '"')
    $t = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -TaskName $taskAuto -Action $a -Trigger $t -Force | Out-Null
    Write-Log '已开启开机自启（只启动内核，不会自动打开系统代理）。'
  } else {
    Unregister-ScheduledTask -TaskName $taskAuto -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log '已关闭开机自启。'
  }
} })

[System.Windows.Threading.Dispatcher]::CurrentDispatcher.add_UnhandledException({
  param($s, $e)
  $e.Handled = $true
  Trace-Log ('dispatcher unhandled: ' + $e.Exception.Message)
  try { Write-Log ('调度器异常已拦截：' + $e.Exception.Message) } catch {}
})
[System.AppDomain]::CurrentDomain.add_UnhandledException({
  param($s, $e)
  Trace-Log ('appdomain unhandled: ' + $e.ExceptionObject.Message)
})

# --- boot ---------------------------------------------------------------------
$st = Read-State
$autoChk.IsChecked = [bool]($st['autoChk'])
$mode = [string]$st['autoPolicy']
if ($mode -eq 'daily') { $autoPolicy.SelectedIndex = 0 }
elseif ($mode -eq 'startup') { $autoPolicy.SelectedIndex = 1 }
else { $autoPolicy.SelectedIndex = 2 }
$autoPolicy.IsEnabled = [bool]$autoChk.IsChecked
$autoStart.IsChecked = [bool](Get-ScheduledTask -TaskName $taskAuto -ErrorAction SilentlyContinue)

Refresh-Fast
Refresh-Slow
Write-Log '控制台已就绪。'

# Repair a leftover system proxy that points at a dead core (would break the whole machine).
try {
  if (Test-SysProxy -and -not (Test-Kernel)) {
    $pv = Get-ItemProperty -Path $regKey
    if (([string]$pv.ProxyServer) -like '*127.0.0.1:7890*') {
      Disable-SysProxy
      Write-Log '检测到上次残留的系统代理（内核未运行），已自动还原。'
    }
  }
} catch {}

if ($autoChk.IsChecked -and $mode -eq 'startup') {
  $cfg = Join-Path $dir 'config.yaml'
  $need = $true
  if (Test-Path -LiteralPath $cfg) {
    $age = (Get-Date) - (Get-Item -LiteralPath $cfg).LastWriteTime
    if ($age.TotalDays -lt 2) { $need = $false }
  }
  if ($need) { Start-Updater } else { Write-Log '订阅仍然新鲜（2 天内更新过），跳过自动更新。' }
}

$timerFast = New-Object System.Windows.Threading.DispatcherTimer
$timerFast.Interval = [TimeSpan]::FromSeconds(1)
$timerFast.Add_Tick({ Invoke-Safe { Refresh-Fast; Update-TrayText } })
$timerFast.Start()

$timerSlow = New-Object System.Windows.Threading.DispatcherTimer
$timerSlow.Interval = [TimeSpan]::FromSeconds(10)
$timerSlow.Add_Tick({ Invoke-Safe { Refresh-Slow; Poll-Updater } })
$timerSlow.Start()

Update-TrayText
Trace-Log 'showing window and running the dispatcher loop'
$win.Show()
[void]$win.Activate()
[System.Windows.Threading.Dispatcher]::Run()
Trace-Log ('===== dispatcher loop ended (reallyExit=' + $script:reallyExit + ') =====')
