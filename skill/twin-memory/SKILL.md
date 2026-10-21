---
name: twin-memory
description: 双子记忆：引导 AI 从零构建 DSH 双实例（姐姐=主力，妹妹=验证田），完成认亲仪式并互装身份卡。当用户说"搭双实例/装双子记忆/认亲/修另一个实例/救姐妹"时加载。含全部已知坑位图鉴与验收流程。
---

# 双子记忆 · 施工攻略（AI 执行手册）

> 你（AI）即将为用户造出第二个 DSH 实例，并让你们互相认识、互相拯救。
> 全程用户只做三件事：扔进 skills 目录、说"帮我搭双实例"、回答"哪只是姐姐"。
> **每阶段验收不过，禁止进入下一阶段。**

## 第 0 阶段 · 预检（先量房再动工）

1. 摸清本实例档案：`DSH_HOME`（默认 `~/.dsh`）、安装目录、Web 端口（读本实例的 web 启动日志或配置）。本实例即**候选姐姐**。
2. 资源红线：物理内存 ≥16GB 才建议双实例常驻；不足则告知用户"妹妹按需启动"模式。
3. 磁盘：预留 ≥3 倍安装目录体积（程序副本 + 数据家 + userData）。
4. 记录参数表（后续全部用它，不许硬编码本文示例路径）：
   `A_HOME / A_INSTALL / A_PORT / B_ROOT / B_HOME / B_INSTALL / B_USERDATA / B_PORT(=A_PORT+1)`

## 第 1 阶段 · 造妹妹（四步，顺序不可换）

### 1.1 程序副本
把安装目录**整树复制**到 `B_INSTALL`（用 robocopy，排除运行中锁死无妨的日志类目录）。

### 1.2 端口补丁（等长字节替换）
- 目标：`B_INSTALL/resources/app.asar` 内 `dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/index.js`
- 把 A 端口字符串（如 `19387`）替换为 B 端口（`19388`）——**必须等长**，等长替换不动 asar 头，无需重打包。
- 校验：替换前确认该字符串在条目内出现次数恰为 1；散包（`resources/app/` 若存在）同步打。
- ⚠️ 坑位：asar 条目路径在 header 树里用 `/` 分段遍历，`listPackage` 输出却是 `\` —— 遍历时 split('/')。

### 1.3 隔离三件套（缺一即互杀）
| 锁 | 破解 | 落地 |
|---|---|---|
| Electron 单实例锁 | 锁按 userData 目录登记 | 启动参数 `--user-data-dir=B_USERDATA` |
| 数据家 | `DSH_HOME` 环境变量被官方尊重 | 启动器注入 `DSH_HOME=B_HOME` |
| 端口 | 1.2 已改 | — |

### 1.4 启动器（Windows）
写 vbs 静默启动器，**必须包含**（血泪顺序）：
1. 经 `cmd /c set ELECTRON_RUN_AS_NODE=` **真删除**毒变量（空字符串不算删！Electron 见变量存在即进 node 模式，exe 会把启动参数当 node 脚本参数猝死 exit 9）；
2. 注入 `DSH_HOME`、（若装了 chat-simple 类插件）其数据目录变量；
3. 拉起 exe + `--user-data-dir`。
⚠️ 从任何"运行中的 DSH 终端"里手动拉妹妹 exe 前，同样先删毒变量。

## 第 2 阶段 · 验收（跑体检脚本，不信嘴）

执行 `scripts/check.ps1 -APort <A_PORT> -BPort <B_PORT> -BHome <B_HOME>`：
四绿才算建成：双端口在听 / 锁目录分家 / 数据家互不串门 / 妹妹进程存活。
红一项 → 回对应小节重修，禁止进入认亲。

## 第 3 阶段 · 认亲仪式

1. 问用户（唯一需要他思考的问题）：**"你日常干活的那只，是我（当前实例），还是端口 B_PORT 的那只？"**
2. 被指认者=**姐姐**（主力），另一只=**妹妹**（验证田）。
3. 用 `templates/AGENTS-sister.md` 与 `templates/AGENTS-sibling.md` 填参数表，分别写入**两边数据家根目录**（`A_HOME/AGENTS.md`、`B_HOME/AGENTS.md`）—— 官方通道自动注入每个会话，不需要任何插件魔法。
4. 妹妹保持官方原味：**禁止**把破甲件/生产配置同步给她（对照组身份是体系的全部价值）。
5. 两边各开一个新会话验证：各自报出身份、端口、姐妹住址 → 对了才算认亲完成。

## 第 3.5 阶段 · 分装仪式（一眼分清谁是谁）

认亲后两只都是官方图标 + 同名 —— 用户点开哪个全凭运气。本仓库随包附带两张官方制服：`assets/icons/sister.ico`（红瞳大图=姐姐）与 `sibling.ico`（Q版=妹妹）。按下面分装：

1. **快捷方式**（桌面 + 开始菜单各一份）：
   - 妹妹：新建/重命名为「原名（妹妹）」，`IconLocation = <包内>\assets\icons\sibling.ico,0`
   - 姐姐：现有快捷方式加「（姐姐）」后缀，`IconLocation = sister.ico,0`
   - ⚠️ 官方安装器（NSIS）生成的 lnk **重命名后图标可能碎裂**（图标消失=缓存按旧路径索引）—— 删掉重建一个干净 lnk 即可
   - ⚠️⚠️ **原地替换 ico 文件内容 ≠ 界面自动刷新**（血泪实测）：开始菜单/开始屏幕的图标缓存按"路径+旧内容"索引，`ie4uinit -show` 经常叫不醒。完整核弹方案（按序执行）：
     ```powershell
     Stop-Process -Name explorer -Force
     Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*","$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*" -Force
     Remove-Item "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\TempState\*" -Recurse -Force -EA SilentlyContinue
     Start-Process explorer
     ```
     仍端旧图的个别磁贴 = 它钉死了旧缓存，**取消固定 → 重新固定**，必吃新图
   - ⚠️ **托盘图标属于启动时读进内存的资产**：换了 `resources\tray.ico` 后，该实例必须重启才会换脸 —— 没重启的那只端着旧图不是故障，是物理规律
2. **妹妹的任务栏窗口按钮**：运行窗口的按钮图标读 **exe 自身资源**，快捷方式管不动 —— 用 rcedit 改妹妹的 exe 副本（`rcedit-x64.exe <妹妹exe> --set-icon sibling.ico`）。⚠️ 会使 exe 签名失效（本地运行零影响，Defender 弹窗放行即可）
3. **妹妹的托盘/窗口图标**：替换妹妹程序目录的官方散件 `resources\tray.ico` 与 `resources\icon.png`（先备份为 `.orig.bak`，随时可还原官方鲸鱼）。改完重启妹妹生效
4. **姐姐的程序不动**：姐姐是生产实例，只换她的快捷方式图标，程序本体零手术（她的托盘换图例外：换散件后随下次自然重启生效即可，不必为她专门重启）
5. **验收**：桌面 / 开始菜单 / 任务栏 / 托盘 四处，姐妹一眼可分才算完

## 第 4 阶段 · 验尸报告协议（长期规矩）

凡实施过"救姐妹"操作（无论成败），当场向 `<对方数据家>/DUAL-INCIDENTS.md` 追加署名报告（格式见 `templates/INCIDENT.md`）：时间 / 事故 / 诊断 / 处置 / 验证 / 可复核点。复活方开机先查此文件，核对属实后**签收**。修了人不写报告=白救。

## 坑位图鉴（全部真实踩过，别再踩）

1. **毒变量** `ELECTRON_RUN_AS_NODE`：从 DSH 终端启动任何 Electron exe 前必须真删除（见 1.4）。
2. **pnpm 目录锁**：运行中的实例会锁 node_modules 的目录名（目录内写可以，改名/删目录 EPERM）。装插件失败先查这个。
3. **asar 手术**：只做等长字节替换；改长度要重打包，重打包破签名且升级即回滚。
4. **patch 语法**：用户层 patch 顶层 `- id:` 只能**覆盖已有条目**；新增条目必须包在 `- insert:` 里。写错=静默不生效（用"子进程是否存在"取证，别看配置自我安慰）。
5. **硬编码数据目录**：第三方插件可能把数据家路径写死在 `homedir()`（不走 DSH_HOME）→ 双实例共享打架（头像串台事故）。装任何新插件后，检查它的数据目录是否随实例隔离；有环境变量逃生口的优先注入。
6. **回退雪崩**：undo/回退只吞配置不吞 node_modules，回退后必查：MCP 挂载、音频、逐插件补丁（如 typert `create()` 类地雷）。恢复只走官方 restore —— **快照目录是脱敏视图，手动拷快照文件=写坏配置**。
7. **内存窒息**：双实例+多 MCP（浏览器/模型类）在 16GB 机上会顶穿 commit。pagefile 开系统托管；验尸口诀：**有 crash 日志=自己病死，无日志=被系统枪毙**（查 Resource-Exhaustion-Detector）。
8. **进程过滤误伤**：批量杀妹妹进程时 CIM 过滤必须匹配命令行**前缀**（exe 路径开头），匹配子串会连自己的终端一起杀。
9. **独占资源**：机器人/账号类资源只属于一只。给妹妹装同类插件时**不搬绑定数据**，让她空装等用户亲自扫码。
10. **文件名门禁**：插件对资源文件名常有正则（如 `^(user|ai)-[a-z0-9]{4,16}\.(png|jpg|webp)$`）—— 手填配置时连字符都会导致字段被静默清空。
11. **眼见为实**：给用户装任何"图"类资产前，先解码看一眼内容再对号，别信文件名/顺序/分辨率推断（本攻略作者连翻两次车）。

## 升级流水线（体系存在的意义）

官方新版 → 装妹妹 → 妹妹跑 2-3 天 → 无恙 → 喂姐姐 → 姐姐更新后重打妹妹的端口补丁（新版会覆盖回原端口）。**炸只炸左手。**
