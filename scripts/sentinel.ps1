# 双子记忆 · 哨兵 v2（护士语义收窄版）
# 铁律：只救"垂死"，不复活"已故"。
#   半死（进程树在、端口死）→ 尸体，杀树重拉
#   全没 + 近期 crash 日志   → 病死，重拉
#   全没 + 无 crash 日志     → 用户主动关闭 —— 尊重退出，绝不打扰（误杀根因已切除）
# 用法: sentinel.ps1              → 巡检 A+B
#       sentinel.ps1 -Target B|-A → 单救
param([ValidateSet('A','B')][string]$Target, [switch]$Quiet)
$ErrorActionPreference = 'Continue'
$logFile = 'D:\dsh\sentinel.log'
function Log($m) { $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m; Add-Content $logFile $line -Encoding UTF8; if (-not $Quiet) { Write-Host $line } }

# 防重入锁
$lock = 'D:\dsh\sentinel.lock'
if ((Test-Path $lock) -and ((Get-Date) - (Get-Item $lock).LastWriteTime).TotalMinutes -lt 10) { Log '已有哨兵在跑，跳过'; exit 0 }
Set-Content $lock (Get-Date)

function Test-Port([int]$port) { [bool](Get-NetTCPConnection -State Listen -LocalPort $port -EA SilentlyContinue) }
function Confirm-Dead([int]$port) {           # 三次×10秒复验，防网络栈抖动误判
  for ($i = 0; $i -lt 3; $i++) {
    if (Test-Port $port) { return $false }
    Start-Sleep -Seconds 10
  }
  return $true
}
function Get-TreeCount([string]$prefix) {     # 命令行前缀匹配（防误伤铁律：只用 StartsWith）
  @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine.StartsWith($prefix) }).Count
}
function Test-FreshCrash([string]$logsDir) {  # 30 分钟内有无 crash 日志 = 病死 vs 主动关 的分水岭
  $c = Get-ChildItem $logsDir -Filter 'crash-*' -EA SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  return ($c -and ((Get-Date) - $c.LastWriteTime).TotalMinutes -lt 30)
}
function Stop-Corpse([string]$prefix) {
  $rem = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine.StartsWith($prefix) })
  foreach ($k in $rem) { Stop-Process -Id $k.ProcessId -Force -EA SilentlyContinue }
  return $rem.Count
}
function Send-SOS($who, $detail) {
  $home_ = if ($who -eq 'B') { 'D:\dsh\DSH-HOME-B' } else { 'C:\Users\Administrator\.dsh' }
  $sos = "`n## {0} · 署名：哨兵（自动护士）`n【事故】{1} 抢救失败`n【诊断】{2}`n【处置】按护士权限施救（拉起/幂等补丁）后仍无监听`n【请求】医生（另一只实例 AI 或用户）介入：回退或重建`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $who, $detail
  Add-Content (Join-Path $home_ 'DUAL-INCIDENTS.md') $sos -Encoding UTF8
  try {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("{1} 实例抢救失败，遗书已留 DUAL-INCIDENTS.md。诊断：{2}" -f '', $who, $detail, '双子记忆 · 哨兵报警', 'OK', 'Error') | Out-Null
  } catch { }
  Log "!! $who S.O.S. 已落台账"
}

$A_PREFIX = '"C:\Users\Administrator\AppData\Local\Programs\DeepSeek Harness\DeepSeek Harness.exe"'
$B_PREFIX = '"D:\dsh\DSH-B'
$A_EXE = 'C:\Users\Administrator\AppData\Local\Programs\DeepSeek Harness\DeepSeek Harness.exe'
$A_LOGS = "$env:APPDATA\@deepseek-ai\dsh-desktop\logs"
$B_LOGS = 'D:\dsh\DSH-B\userdata\logs'

function Rescue-B {
  if (Test-Port 19388) { return $true }
  if (-not (Confirm-Dead 19388)) { return $true }
  $tree = Get-TreeCount $B_PREFIX
  if ($tree -eq 0 -and -not (Test-FreshCrash $B_LOGS)) { Log 'B 干净消失且无 crash 日志 = 用户主动关闭，尊重退出，不干预'; return $true }
  Log "B 确认死亡（树=$tree），L1：杀残尸+无声拉起"
  [void](Stop-Corpse $B_PREFIX)
  Start-Sleep -Seconds 3
  & cscript.exe //nologo 'D:\dsh\DSH-B\launch-b.vbs'
  Start-Sleep -Seconds 75
  if (Test-Port 19388) { Log 'B L1 救活'; return $true }
  # L2：端口补丁检查（考试抓出的顺序 bug 已修：先清尸释放 asar 句柄→再补丁→验证→拉起）
  $patchOut = & 'C:\nodejs\node.exe' 'D:\dsh\DSH-B\patch-asar-any.mjs' 'D:\dsh\DSH-B\app\resources\app.asar' 'dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/index.js' '19388' '19387' --verify-only 2>&1 | Out-String
  if ($patchOut -match 'occurrences=0') {
    Log 'B L2：端口补丁丢失 → 清尸释放句柄 → 幂等重破甲 → 验证'
    [void](Stop-Corpse $B_PREFIX); Start-Sleep -Seconds 5
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'D:\dsh\DSH-B\新版后重破甲.ps1' 2>&1 | Out-Null
    $recheck = & 'C:\nodejs\node.exe' 'D:\dsh\DSH-B\patch-asar-any.mjs' 'D:\dsh\DSH-B\app\resources\app.asar' 'dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/index.js' '19388' '19387' --verify-only 2>&1 | Out-String
    if ($recheck -match 'occurrences=1') { Log 'B L2：补丁恢复且验证通过，重拉' }
    else { Send-SOS 'B' '重破甲后验证仍失败（句柄或磁盘异常），需医生人工' ; return $false }
    & cscript.exe //nologo 'D:\dsh\DSH-B\launch-b.vbs'; Start-Sleep -Seconds 90
    if (Test-Port 19388) { Log 'B L2 救活'; return $true }
  }
  Send-SOS 'B' '拉起+重破甲后 19388 仍无监听'
  return $false
}

function Rescue-A {
  if (Test-Port 19387) { return $true }
  if (-not (Confirm-Dead 19387)) { return $true }
  $tree = Get-TreeCount $A_PREFIX
  if ($tree -eq 0 -and -not (Test-FreshCrash $A_LOGS)) { Log 'A 干净消失且无 crash 日志 = 用户主动关闭，尊重退出，不干预'; return $true }
  Log "A 确认死亡（树=$tree），L1：杀残尸+拉起"
  [void](Stop-Corpse $A_PREFIX)
  Start-Sleep -Seconds 3
  Start-Process $A_EXE
  Start-Sleep -Seconds 75
  if (Test-Port 19387) { Log 'A L1 救活'; return $true }
  # L2：flow 地雷（退役存档条款：插件在且缺补丁才动，纯加法+备份）
  $f = 'C:\Users\Administrator\.dsh\profiles\desktop\node_modules\deepseek-flow\lib\typert.descriptors.js'
  if ((Test-Path $f) -and ((Get-Content $f -Raw) -notmatch 'create:')) {
    Copy-Item $f "$f.nurse.bak" -Force
    $t = (Get-Content $f -Raw) -replace [regex]::Escape('  schema: z.unknown()'), "  schema: z.unknown(),`n  create: () => z.unknown()"
    [IO.File]::WriteAllText($f, $t)
    Log 'A L2：flow create() 已补（备份 .nurse.bak），再拉起'
    Start-Process $A_EXE; Start-Sleep -Seconds 75
    if (Test-Port 19387) { Log 'A L1 救活'; return $true }
  }
  Send-SOS 'A' '拉起+排雷后 19387 仍无监听'
  return $false
}

if ($Target -eq 'B') { $ok = Rescue-B }
elseif ($Target -eq 'A') { $ok = Rescue-A }
else { $okB = Rescue-B; $okA = Rescue-A; $ok = $okA -and $okB }

# 器官巡检（E3 考试发现的盲区：植物人=端口在听但插件器官缺席）
function Test-Organ([int]$port) {
  $hp = (Get-NetTCPConnection -State Listen -LocalPort $port -EA SilentlyContinue | Select-Object -First 1).OwningProcess
  if (-not $hp) { return }
  $kids = @(Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $hp -and $_.Name -match 'python|scrapling|pwsh|node' }).Count
  if ($kids -lt 1) { Log "警告：端口 $port 在听但宿主无器官子进程（疑似配置植物人态），需医生查 cordis —— 哨兵不越权自动处理" }
}
if (Test-Port 19388) { Test-Organ 19388 }
if (Test-Port 19387) { Test-Organ 19387 }
Remove-Item $lock -Force -EA SilentlyContinue
if (-not $Quiet) { exit $(if ($ok) { 0 } else { 1 }) }
