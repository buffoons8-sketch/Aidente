# Aidente 本地 Codex 接手说明

更新日期：2026-09-28。以下早期章节保留接手时的历史快照。

## 6.1 / Build 21 发行交接

用户已明确要求将本轮充电控制修复和横向状态栏调整更新为 6.1 并上传 GitHub，已授权提交、推送及发行。本轮源码、主程序与读取服务版本统一为 6.1 / Build 21；下方“本地未提交、保留 6.0.2”的描述仅表示发行前各次验证的状态。

本轮包含原始小数电量向上取整一次、暂停区间冻结、清醒与睡眠保持分离、持续实际功率验证，以及 20/26 点宽的横向电池图标。发行入口为 https://github.com/buffoons8-sketch/Aidente/releases/tag/v6.1 ，安装包采用原有 ad-hoc 完整性签名，并非 Developer ID 或 Apple 公证版。升级后应用与后台身份改变，需要从应用中修复控制服务并通过系统管理员授权。

构建与发行验证见 `maintenance-test-notes.md` 的 6.1 章节。实际电池功率和长时间睡眠仍需按硬件场景分别核实，不能以发行或测试通过代替；本轮没有把先前约半秒的睡眠切换写成持续睡眠通过。

## 2026-09-28 本地状态栏调整

用户要求恢复紧凑横向电池，取消电量文字随填充反色。当前图标从左向右填充，有电部分用较浅状态色，无电部分用浅灰蓝，数字与充电标记统一深色；纯图标状态栏宽 20 点，内置数字宽 26 点，左右各 1 点留白。共享布局常量同时用于 SwiftUI 和 NSStatusItem 宽度计算。

已更新 `/Applications/Aidente.app` 及控制服务身份登记，GUI、后台与 manifest 一致，原设置保持上限 60%、巡航范围 5 个百分点。构建、签名和 138 项充电回归通过。原生 SwiftUI 预览检查 0%、5%、50%、79%、100%、低电量模式、状态颜色关闭及功率组合，明暗背景均可辨识，预览位于 `Dist/Aidente-status-horizontal-preview-20260928.png`。实机更新后的功率与设置记录在 `Dist/horizontal-status-install-20260928.json`。这些状态栏调整仍为本地未提交修改，版本保留 6.0.2 / Build 20。

## 2026-09-28 本地限充保持修正

本会话用户已授权直接修复、安装和实机测试，无需重复确认；管理员密码仍只由 macOS 系统弹窗接收。当前版本仍为 6.0.2 / Build 20，后续充电修正保留为未提交修改，本轮未重新发布 GitHub。

- 暂停保持使用未取整的硬件电量，在写入固件前向上取整一次。例如 54.66% 使用 55% 边界，避免写成 54% 后触发电池供电。暂停期间冻结完整上下限，拖动设置不重复写入；清醒、睡眠保持分别保存，唤醒恢复清醒策略。
- 已替换 `/Applications/Aidente.app` 并更新本地控制服务；主程序、后台及 root manifest 一致。构建、签名及 138 项充电回归检查通过。
- 15:36–15:40 共 19 次实机样本：电池全部 0.00 W，适配器 5.62–18.59 W，强制放电关闭，固件区间保持 50–55%、激活状态 2。通过应用入口切换 50%、45%、52% 后恢复原设置 60%。
- 35 秒睡眠测试收到 willSleep 后约半秒即恢复；验证了切换及恢复后供电，未验证持续睡眠或合盖。不要把该结果当作长时间睡眠、低电量充至上限或所有机型固件的完整验收。
- 本轮证据在 `Dist/fractional-*-20260928.json`、`Dist/fractional-control-log-20260928.txt`。更新后的只读探测器为 `Build/diagnose_smc`，暂停是否成立仍以实际电池功率为准，不能仅依赖寄存器接受或 `chargingInhibited` 的阈值推断。

## 6.0.2 发布准备更新

用户已明确授权更新小版本并发布 GitHub。当前源码版本为 6.0.2 / Build 20，包含竖向紧凑状态栏图标及以下管理员安装/固件控制修正。下文 Git 状态、已安装版本及历史实测是接手时快照。发布产物沿用 ad-hoc 签名，不是 Developer ID 或 Apple 公证版；未改变 `AIDENTE_RELEASE_BUILD=1` 的证书要求。
此文件用于跨任务接手，不是聊天记录的完整导入。

## 在桌面端接入

添加/打开本地项目，选择本文件所在的 Aidente 文件夹作为主文件夹：

`/Users/buffoons/Documents/Codex/2026-07-24/apphousekitchen-aldente-battery-care-and-monitoring/work/Aidente`

直接使用这个现有目录。不要用 GitHub 的重新克隆版本替代；接手时的重要修复曾处于未提交状态，后续以实际 Git 状态为准。如选择 worktree，必须显式包含仍未提交的工作，否则不能保证拿到修复。

官方项目说明：https://learn.chatgpt.com/docs/projects

本次只准备交接文件，未安装独立 Codex 应用、未创建新任务，也未迁移完整聊天历史。检查时 `/Applications/ChatGPT.app` 存在，`/Applications/Codex.app` 不存在；不代表其他目录一定未安装。

## 给新任务的第一条消息

> 请接手此目录中的 Aidente 项目。先完整阅读 AGENTS.md、CODEX_HANDOFF.md、administrator-install-notes.md，再检查 Git 未提交修改。保留现有代码，不改版本号、不上传 GitHub、不自动替换已安装应用。先做只读检查，向我确认你理解当前状态和未解决问题，再继续充电控制相关诊断。不要把后台服务正常等同于充电与睡眠问题全部修复。

## 2026-09-20 接手时工作区状态（历史）

- 分支：`aidente-main`。
- HEAD：`951bca403dd8aa8a26168b3ae62f6eb1bb0322c8`。
- origin：`https://github.com/buffoons8-sketch/Aidente.git`。
- upstream：`https://github.com/srimanachanta/Stasis.git`（参考项目，勿误推送）。
- 存在大量已跟踪文件修改及未跟踪的新源码、测试、说明文件。用 `git status --short` 查看实时清单，不能只看 HEAD。
- `/Applications/Aidente.app` 的版本读取为 6.0.1 / Build 19。
- 本地测试包存在：`Dist/Aidente-admin-install-test-20260920-r3.zip`。
- 本次交接准备没有重新运行硬件测试或发布新版本。

## 前序工作结果（历史实测，接手后需重新核实）

1. 旧 SMAppService 方式在本机遇到 Launch Constraint Violation，即使 ad-hoc 完整性检查正常也无法启动。
2. 用户无付费开发者账号，明确选择管理员授权的传统 LaunchDaemon 安装方式。无需关闭系统保护，但这不是 Apple 开发者签名或公证方案。
3. 首次安装错误 65 已定位为 `codesign -dvv` 不输出 CDHash；改为 `-dvvv` 并加入具体错误说明，测试执行生产提取语句。
4. r3 管理员安装及 XPC 健康检查成功，历史日志出现 `CONTROL_SERVICE_HEALTH_OK` / `LOCAL_CONTROL_HEALTH_OK`。
5. 旧固件暂停方案把上限写成 1%，可能持续消耗电池，已移除。普通限充写入真实目标；手动暂停固定当时的硬件百分比，不能随下降不断降低上限。
6. 上次硬件读回上限 60%、下限 55%，不再是 1%。但高于上限时仍观察到电池供电；不能宣称已实现“暂停充电时始终适配器供电”。
7. 历史测试结果：83 项充电/固件回归检查、9 项安装器检查通过。睡眠/唤醒等实机验收尚不完整。

## 当前方案入口

- `Aidente/Services/ChargingHelperManager.swift`：显式安装/修复、健康检查、失败锁定、XPC 连接。
- `Aidente/Services/LocalControlInstaller.swift`：系统管理员授权、哈希和签名信息、安装脚本传值。
- `BuildSupport/install_local_control.sh`：root 安装、目标目录校验、备份与失败恢复。
- `Shared/LocalControlIdentity.swift`：固定路径、服务标签、签名要求。
- `ChargingHelper/main.swift`：root 服务入口、客户端身份检查、恢复模式。
- `ChargingHelper/ChargingHelper.swift`：串行硬件策略、睡眠/唤醒、看门狗、原始固件设置恢复。
- `Shared/ChargeControlPolicy.swift`：固件暂停上限固定策略及充电决策。
- `SMCPower/SMCBattery.swift`、`SMCPower/FirmwareChargeLimit.swift`：SMC 访问和原生固件限充；硬件百分比使用 AppleRawCurrentCapacity / AppleRawMaxCapacity，可能与菜单显示不同。
- `Aidente/Services/ChargeManager.swift`：GUI 策略合并、刷新与读回验证。
- `Aidente/StatusBarManager.swift`、`Aidente/Views/BatteryIndicatorView.swift`：紧凑状态栏电池图标。

## 系统组件及安全边界

- 活跃方案的服务标签：`com.aidente.app.control.local`。
- 后台目录：`/Library/PrivilegedHelperTools/com.aidente.app.local`。
- 启动配置：`/Library/LaunchDaemons/com.aidente.app.control.local.plist`。
- 主程序固定安装路径：`/Applications/Aidente.app`。
- manifest 固定管理员批准的主程序 cdhash 和文件哈希；GUI 同时校验后台 cdhash。重新构建并替换主程序后通常需要再次授权。
- `.aidente-local.*` 是 root 专用回滚备份，不要批量清理。
- 关闭管理/卸载需先恢复电池默认控制，失败保留服务并报错。
- `--check-control-service` 在身份不匹配时可能弹管理员安装框，不能当成纯只读命令。
- 不随意执行 `--unregister-helper`，它会卸载/恢复硬件状态。

## 构建和验证

在项目根目录执行：

```sh
zsh BuildSupport/build_app.sh
zsh BuildSupport/test_charging.sh
sh -n BuildSupport/install_local_control.sh
git diff --check
```

构建输出 `Dist/Aidente.app`。本机此前 Swift 与默认 SDK 有兼容问题，脚本使用 `/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk`；不要随意切换默认 SDK。常规测试构建不要求开发者证书；`AIDENTE_RELEASE_BUILD=1` 仍要求有效 Developer ID，未改成无证书发行流程。

安装器单独回归（先构建）：

```sh
swiftc -parse-as-library BuildSupport/tests/LocalInstallerTests.swift \
  Aidente/Services/LocalControlInstaller.swift \
  -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk \
  -target arm64-apple-macosx14.0 -I Build/Modules \
  -L Build -lAidenteShared -o Build/LocalInstallerTests
Build/LocalInstallerTests
```

`Build/diagnose_smc` 可能是旧链接产物。使用它的高层判断前，按 `BuildSupport/diagnose_smc.swift` 重新编译，不能仅因文件存在就信任其结果。

## 后续优先级

1. 只读确认 GUI、root 后台版本/哈希对应，服务稳定且无新错误。
2. 与用户约定实机测试：正常到达上限、手动暂停、睡眠/唤醒、断开/重新接入电源、系统升级后的服务恢复。
3. 核实新固件在超过上限时使用电池的行为边界；不要再采用 0–1% 上限模拟暂停。不能承诺软件强制消除固件限制。
4. 单独验证升级重新授权、安装失败回滚、卸载恢复；保护安全更新校验及 GitHub API 限流的备用检查路径。
5. 只有用户决定发行后，才确定版本号并进行 GitHub 发布。

## 说明文件的时效

优先阅读 `administrator-install-notes.md`（当前方案）。`control-service-repair-notes.md` 是更早的签名阻塞分析，已被管理员安装方案部分取代；`maintenance-test-notes.md` 包含之前的整体修复记录。遇到矛盾以源码、当前实测和用户新指令为准。
