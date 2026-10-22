# 双子记忆 · 哨兵（护士巡逻版）
# 权限铁律：只做"做坏了也不会更坏"的事 —— 拉起 / 杀已死之尸 / 幂等纯加法补丁。
# 一切回退、删除、改写决策 = 留给医生（另一只实例的 AI）。
# 用法: sentinel.ps1              → 巡检 A+B（计划任务用）
#       sentinel.ps1 -Target B    → 只救 B（手动一键）
#       sentinel.ps1 -Target A    → 只救 A
param([ValidateSet('A','B')][string]$Target, [switch]$Quiet)
$ErrorActionPreference = 'Continue'
$logFile = 'D:\dsh\sentinel.log'
function Log($m) { $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m; Add-Content $logFile $line; if (-not $Quiet) { Write-Host $line } }

# 防重入锁（上一轮哨兵没跑完就跳过本轮）
$lock = 'D:\dsh\sentinel.lock'
if ((Test-Path $lock) -and ((Get-Date) - (Get-Item $lock).LastWriteTime).TotalMinutes -lt 10) { Log '哨兵已有实例在跑，本轮跳过'; exit 0 }
Set-Content $lock (Get-Date)

function Test-Alive([int]$port) { [bool](Get-NetTCPConnection -State Listen -LocalPort $port -EA SilentlyContinue) }

function Stop-CorpseTree([string]$prefix) {
  # 只杀命令行以 prefix 开头的进程树（前缀匹配防误伤，血泪教训）
  $rem = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine.StartsWith($prefix) })
  foreach ($k in $rem) { Stop-Process -Id $k.ProcessId -Force -EA SilentlyContinue }
  return $rem.Count
}

function Send-SOS($who, $detail) {
  # 遗书：写进"活人"的台账 + 尝试弹窗；机器层到此为止，喊医生
  $home_ = if ($who -eq 'B') { 'D:\dsh\DSH-HOME-B' } else { 'C:\Users\Administrator\.dsh' }
  $sos = "`n## {0} · 署名：哨兵（自动护士）`n【事故】{1} 三级护理失败`n【诊断】{2}`n【处置】拉起/幂等补丁均已尝试`n【请求】请医生（另一只实例的 AI 或用户）介入：回退或重建`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $who, $detail
  Add-Content (Join-Path $home_ 'DUAL-INCIDENTS.md') $sos
  try {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("{1} 实例救援失败，已留遗书于 DUAL-INCIDENTS.md，请让另一只实例的 AI 施救。`n`n诊断：{2}" -f '', $who, $detail, '双子记忆 · 哨兵报警', 'OK', 'Error') | Out-Null
  } catch { }
  Log "!! $who S.O.S. 已落台账并尝试弹窗"
}

function Rescue-B {
  if (Test-Alive 19388) { return $true }
  Log 'B 死亡，L1：杀残尸+无声拉起'
  [void](Stop-CorpseTree '"D:\dsh\DSH-B')
  Start-Sleep -Seconds 3
  & cscript.exe //nologo 'D:\dsh\DSH-B\launch-b.vbs'
  Start-Sleep -Seconds 60
  if (Test-Alive 19388) { Log 'B L1 救活'; return $true }
  # L2：幂等重破甲（端口补丁器：已打过会自己拒绝，纯加法安全）
  Log 'B L2：检查 asar 端口补丁是否被新版覆盖'
  $patchOut = & 'C:\nodejs\node.exe' 'D:\dsh\DSH-B\patch-asar-any.mjs' 'D:\dsh\DSH-B\app\resources\app.asar' 'dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/index.js' '19388' '19387' --verify-only 2>&1 | Out-String
  if ($patchOut -match 'occurrences=0') {
    Log 'B L2：补丁确实丢了 → 跑重破甲脚本（幂等）'
    & pwsh -NoProfile -ExecutionPolicy Bypass -File 'D:\dsh\DSH-B\新版后重破甲.ps1' 2>&1 | Out-Null
    [void](Stop-CorpseTree '"D:\dsh\DSH-B'); Start-Sleep -Seconds 3
    & cscript.exe //nologo 'D:\dsh\DSH-B\launch-b.vbs'; Start-Sleep -Seconds 60
    if (Test-Alive 19388) { Log 'B L2 救活'; return $true }
  }
  Send-SOS 'B' '拉起+重破甲后 19388 仍无监听'
  return $false
}

function Rescue-A {
  if (Test-Alive 19387) { return $true }
  Log 'A 死亡，L1：杀残尸+拉起官方 exe'
  [void](Stop-CorpseTree '"C:\Users\Administrator\AppData\Local\Programs\DeepSeek Harness\DeepSeek Harness.exe"')
  Start-Sleep -Seconds 3
  Start-Process 'C:\Users\Administrator\AppData\Local\Programs\DeepSeek Harness\DeepSeek Harness.exe'
  Start-Sleep -Seconds 60
  if (Test-Alive 19387) { Log 'A L1 救活'; return $true }
  # L2：flow 地雷纯加法补丁（缺 create 才补，先备份，幂等）
  Log 'A L2：排查 flow 地雷'
  $f = 'C:\Users\Administrator\.dsh\profiles\desktop\node_modules\deepseek-flow\lib\typert.descriptors.js'
  if ((Test-Path $f) -and ((Get-Content $f -Raw) -notmatch 'create:')) {
    Copy-Item $f "$f.nurse.bak" -Force
    $t = (Get-Content $f -Raw) -replace [regex]::Escape('  schema: z.unknown()'), "  schema: z.unknown(),`n  create: () => z.unknown()"
    [IO.File]::WriteAllText($f, $t)
    Log 'A L2：flow create() 已补（备份 .nurse.bak），再拉起'
    Start-Process 'C:\Users\Administrator\AppData\Local\Programs\DeepSeek Harness\DeepSeek Harness.exe'
    Start-Sleep -Seconds 60
    if (Test-Alive 19387) { Log 'A L2 救活'; return $true }
  }
  Send-SOS 'A' '拉起+flow 排雷后 19387 仍无监听'
  return $false
}

# ── 主流程 ──
if ($Target -eq 'B') { $ok = Rescue-B }
elseif ($Target -eq 'A') { $ok = Rescue-A }
else {
  $okB = Rescue-B
  $okA = Rescue-A
  $ok = $okA -and $okB
}
Remove-Item $lock -Force -EA SilentlyContinue
if (-not $Quiet) { exit $(if ($ok) { 0 } else { 1 }) }
