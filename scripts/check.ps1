# 双子记忆 · 双实例体检（四绿验收）
# 用法: .\check.ps1 -APort 19387 -BPort 19388 -BHome D:\dsh\DSH-HOME-B [-BInstall <path>]
param(
  [int]$APort = 19387,
  [int]$BPort = 19388,
  [string]$BHome = '',
  [string]$BInstall = ''
)
$ErrorActionPreference = 'SilentlyContinue'
$pass = 0; $fail = 0
function Assert($name, $ok, $detail) {
  if ($ok) { Write-Host ("[GREEN] {0}  {1}" -f $name, $detail) ; $script:pass++ }
  else     { Write-Host ("[RED]   {0}  {1}" -f $name, $detail) ; $script:fail++ }
}
# 1) 双端口在听
$a = Get-NetTCPConnection -State Listen -LocalPort $APort
$b = Get-NetTCPConnection -State Listen -LocalPort $BPort
Assert 'A 端口监听' ([bool]$a) "$APort -> PID $($a[0].OwningProcess)"
Assert 'B 端口监听' ([bool]$b) "$BPort -> PID $($b[0].OwningProcess)"
# 2) 锁目录分家（两边主进程 user-data-dir 不同）
$procs = Get-CimInstance Win32_Process -Filter "Name like '%Harness%' or Name like '%dsh%'" | Where-Object { $_.CommandLine -match 'user-data-dir' }
$udDirs = $procs | ForEach-Object { [regex]::Match($_.CommandLine, '--user-data-dir="?([^"" ]+)').Groups[1].Value } | Sort-Object -Unique
Assert 'userData 锁分家' ($udDirs.Count -ge 2) ($udDirs -join ' | ')
# 3) 数据家互不串门（B 的 DSH_HOME 存在且非 A 的 ~/.dsh）
$bHomeOk = $BHome -and (Test-Path $BHome) -and ($BHome -ne "$env:USERPROFILE\.dsh")
Assert 'B 数据家独立' $bHomeOk $BHome
# 4) B 程序副本端口补丁（若给了 BInstall，检查 asar 里 B 端口存在）
if ($BInstall) {
  $asar = Join-Path $BInstall 'resources\app.asar'
  $ok = $false
  if (Test-Path $asar) {
    $bytes = [IO.File]::ReadAllBytes($asar)
    $txt = [Text.Encoding]::ASCII.GetString($bytes)
    $ok = $txt.Contains("$BPort") -and -not $txt.Contains("localPort: $APort")
  }
  Assert 'B 端口补丁在位' $ok $asar
} else {
  Write-Host '[SKIP]  端口补丁检查（未传 -BInstall）'
}
Write-Host ''
Write-Host ("结果: {0} 绿 / {1} 红" -f $pass, $fail)
if ($fail -eq 0) { Write-Host '✓ 双实例健康，可以认亲' ; exit 0 } else { Write-Host '✗ 有红项，回攻略对应小节重修' ; exit 1 }
