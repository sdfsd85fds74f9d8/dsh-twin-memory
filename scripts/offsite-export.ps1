# 双子记忆 · 异地保险柜（中立区备份，快照不能和房子一起烧）
# 用法: offsite-export.ps1          → 备份 A+B
#       offsite-export.ps1 -Only A  → 只备份 A
param([ValidateSet('A','B')][string]$Only)
$ErrorActionPreference = 'Continue'
$dest = 'D:\dsh\offsite-backup'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$log = Join-Path $dest 'offsite.log'

function Backup-Home($tag, $home_, $extraDirs) {
  if (-not (Test-Path $home_)) { Write-Output "[$tag] 数据家不存在，跳过"; return }
  $outDir = Join-Path $dest $tag
  New-Item -ItemType Directory -Force $outDir | Out-Null
  $stage = Join-Path $env:TEMP "offsite-$tag-$stamp"
  Remove-Item $stage -Recurse -Force -EA SilentlyContinue
  New-Item -ItemType Directory -Force "$stage\profiles\desktop" | Out-Null
  # 核心配置四件套 + 豁免 + 身份卡 + 台账
  foreach ($f in 'package.json','pnpm-lock.yaml','cordis.yml','cordis.patch.yml','compatibility.json') {
    Copy-Item (Join-Path $home_ "profiles\desktop\$f") "$stage\profiles\desktop\" -Force -EA SilentlyContinue
  }
  Copy-Item (Join-Path $home_ 'AGENTS.md') $stage -Force -EA SilentlyContinue
  Copy-Item (Join-Path $home_ 'DUAL-INCIDENTS.md') $stage -Force -EA SilentlyContinue
  # 技能与攻略
  foreach ($d in @('skills') + $extraDirs) { Copy-Item (Join-Path $home_ $d) "$stage\$d" -Recurse -Force -EA SilentlyContinue }
  # undo 快照库的 manifest（小、含恢复索引；大 blob 不动，本机库才是主力）
  Copy-Item (Join-Path $home_ 'undo-snapshots') "$stage\undo-snapshots" -Recurse -Force -EA SilentlyContinue
  $zip = Join-Path $outDir "$stamp.zip"
  Compress-Archive -Path "$stage\*" -DestinationPath $zip -Force -EA SilentlyContinue
  Remove-Item $stage -Recurse -Force -EA SilentlyContinue
  # 保留最近 10 份
  Get-ChildItem $outDir -Filter '*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -Skip 10 | Remove-Item -Force
  if (Test-Path $zip) { Write-Output ("[{0}] 备份完成 {1} ({2:N0} KB)" -f $tag, (Split-Path $zip -Leaf), ((Get-Item $zip).Length/1KB)) }
  else { Write-Output "[$tag] 备份失败（zip 未生成）" }
}

New-Item -ItemType Directory -Force $dest | Out-Null
$results = @()
if (-not $Only -or $Only -eq 'A') { $results += Backup-Home 'A' 'C:\Users\Administrator\.dsh' @() }
if (-not $Only -or $Only -eq 'B') { $results += Backup-Home 'B' 'D:\dsh\DSH-HOME-B' @('chat-simple-data') }
$results | ForEach-Object { Add-Content $log "$stamp $_" }
$results
