# 双子记忆 · 哨兵daemon（常驻版，替代计划任务 —— 本机 schtasks 无权限）
# 每 5 分钟巡检一次；每天 03:30 前后触发一次异地备份。
$ErrorActionPreference = 'Continue'
$scripts = Split-Path $MyInvocation.MyCommand.Path
$log = 'D:\dsh\sentinel.log'
Add-Content $log "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') 哨兵 daemon 上岗"
$lastOffsite = (Get-Date).AddDays(-1)
while ($true) {
  try {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'sentinel.ps1') -Quiet
    # 每日异地备份窗口：03:30-04:00 之间且今天没跑过
    $now = Get-Date
    if ($now.Hour -eq 3 -and $now.Minute -ge 30 -and $lastOffsite.Date -lt $now.Date) {
      & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'offsite-export.ps1') | Out-Null
      $lastOffsite = $now
      Add-Content $log "$($now.ToString('yyyy-MM-dd HH:mm:ss')) 异地备份完成"
    }
  } catch { Add-Content $log "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') daemon 异常: $_" }
  Start-Sleep -Seconds 300
}
