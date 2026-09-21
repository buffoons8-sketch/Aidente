# 后台控制服务修复记录（未发布）

## 已确认的故障

本机系统日志记录 AidenteControl 被 `OS_REASON_CODESIGNING / Launch Constraint Violation` 拦截，尚未执行电池控制。后台允许状态不等于可启动状态。当前应用和后台程序为 ad-hoc 签名，本机没有可用代码签名证书。

## 本次改动

- 首次安装无历史指纹时不再立即注销刚注册的服务。
- 启用、修复后必须经过有超时的 XPC ping，收到回应才保存成功指纹、打开管理开关。
- 并发启用/修复复用同一个任务，失败后停止自动重新注册；用户可显式重试。
- 注册/注销前验证应用和后台程序具有有效的 Apple 签名且团队一致；不卸载服务后才发现新版无法签名。
- 诊断日志纳入系统对 AidenteControl 的启动拦截原因，保留脱敏流程。
- 构建支持 `AIDENTE_SIGNING_IDENTITY`；正式构建 `AIDENTE_RELEASE_BUILD=1` 禁止临时签名，并检查 Developer ID Application 签名要求。

## 构建与验证

本地编译：`zsh BuildSupport/build_app.sh`。此包仅用于本地测试，不应当作为恢复充电控制的正式修复包发布。

正式签名：配置有效的 Developer ID Application 证书及私钥后，用 `AIDENTE_SIGNING_IDENTITY` 指定身份，设置 `AIDENTE_RELEASE_BUILD=1` 构建。所有组件使用同一身份。证书私钥不要提交仓库。

只读签名检查：`Aidente.app/Contents/MacOS/Aidente --check-control-signing`。服务集成检查：安装已签名的包后运行 `--check-control-service`（可能注册后台项目，但不下发充电/放电/LED策略）。

正式验收还需要：实际服务启动、暂停充电读回、关闭管理恢复默认、替换安装和睡眠唤醒。未通过这些检查前不要对外宣称修复完成。此轮不改版本号、不上传发行版、不关闭系统安全机制。

参考：Apple DTS https://developer.apple.com/forums/thread/799910 和 https://developer.apple.com/forums/thread/783539 。

## 本机验证结果

- 78 项不写入真实硬件的回归检查通过（含首次注册不注销、版本变更、系统变更）。
- 缺少证书的正式构建会提前失败；指定不存在的证书也会失败，不降级为临时签名。
- `--check-control-signing` 正确报告本机临时签名问题，退出码为 1。
- 未覆盖 `/Applications/Aidente.app`，未操作真实充电开关，未发布 GitHub。
- 待办：配置有效证书后进行服务启动和硬件验收。目前不能宣称“管理充电已恢复”。
