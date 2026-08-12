import Defaults
import Foundation

enum AidenteL10n {
    static var isEnglish: Bool {
        switch Defaults[.appLanguage] {
        case .simplifiedChinese:
            return false
        case .english:
            return true
        case .system:
            guard let preferredLanguage = Locale.preferredLanguages.first?
                .lowercased()
            else {
                return true
            }
            return !preferredLanguage.hasPrefix("zh")
        }
    }

    static func t(_ chinese: String) -> String {
        guard isEnglish else { return chinese }
        return english[chinese] ?? chinese
    }

    static func t(_ chinese: String, _ english: String) -> String {
        isEnglish ? english : chinese
    }

    static func controlError(_ text: String) -> String {
        if text.contains("后台控制服务未连接")
            || text.contains("Background control service is not connected")
        {
            return t(
                "后台控制服务未连接。请修复控制服务后重试。",
                "The background control service is not connected. Repair it and try again."
            )
        }
        if text.contains("充电暂停命令未生效")
            || text.contains("pause charging command did not take effect")
        {
            return t(
                "充电暂停命令未生效。请修复控制服务后重试。",
                "The pause charging command did not take effect. Repair the control service and try again."
            )
        }
        if text.contains("适配器控制未生效")
            || text.contains("Adapter control did not take effect")
        {
            return t(
                "适配器控制未生效。请修复控制服务后重试。",
                "Adapter control did not take effect. Repair the control service and try again."
            )
        }
        if text.contains("SMC") {
            return t(
                "SMC 已接受暂停设置，但系统仍报告电池正在充电。请点“修复控制服务”后重试。",
                "SMC accepted the pause setting, but the system still reports charging. Click Repair Control Service and try again."
            )
        }
        return text
    }

    private static let english: [String: String] = [
        "中文": "Chinese",
        "跟随系统": "System",
        "语言": "Language",
        "切换菜单栏和设置界面的显示语言。": "Follow macOS or choose the language used in the menu bar and settings.",
        "通用": "General",
        "仪表盘": "Dashboard",
        "充电管理": "Charging",
        "计划与自动化": "Schedules",
        "高级": "Advanced",
        "诊断": "Diagnostics",
        "关于": "About",
        "电池养护控制台": "Battery Care Console",
        "设置页面": "Settings Page",
        "界面材质": "Interface Material",
        "选择菜单浮层和设置窗口的透明与虚化程度。": "Choose the transparency and blur used by the menu panel and settings window.",
        "清晰实体": "Solid",
        "毛玻璃": "Glass",
        "高斯柔化": "Frosted",
        "液态玻璃": "Liquid Glass",
        "最高文字对比度": "Maximum text contrast",
        "平衡透明度与清晰度": "Balanced transparency and clarity",
        "更明显的背景虚化": "Stronger background blur",
        "适配 macOS 26/27，旧系统自动使用兼容效果": "Adapts to macOS 26/27 with a compatible fallback on older systems",
        "启动": "Startup",
        "让电池保护在登录后自动开始工作。": "Start battery protection automatically after you sign in.",
        "登录时启动 Aidente": "Launch Aidente at Login",
        "登录当前账户后自动显示菜单栏图标": "Show the menu bar icon after signing in",
        "主菜单呼出": "Dashboard Access",
        "菜单栏图标被系统折叠时，仍然可以打开完整主菜单。": "Open the full dashboard even when macOS hides the menu bar icon.",
        "双击“应用程序”文件夹、启动台或聚焦搜索中的 Aidente 图标，即可打开独立主菜单窗口。": "Double-click Aidente in Applications, Launchpad, or Spotlight to open a standalone dashboard window.",
        "打开主菜单": "Open Dashboard",
        "菜单栏实时读数": "Live Menu Bar Readout",
        "在电量、当前系统功率或两者同时显示之间切换。": "Show battery level, live system power, or both.",
        "菜单栏显示内容": "Menu Bar Content",
        "实时电量": "Battery Level",
        "实时功率": "Live Power",
        "电量与功率": "Battery & Power",
        "电量数字位置": "Battery Number Position",
        "不显示": "Hidden",
        "图标旁": "Next to Icon",
        "图标内": "Inside Icon",
        "用颜色显示电池状态": "Use Color for Battery State",
        "充电、接通电源、低电量使用不同颜色": "Use different colors for charging, plugged in, and low battery",
        "通知": "Notifications",
        "控制 Aidente 何时向你报告充电状态。": "Choose when Aidente reports charging status.",
        "关闭全部通知": "Disable All Notifications",
        "充电状态变化时通知": "Notify on Charging Changes",
        "暂停或恢复充电时发送系统通知": "Send a notification when charging pauses or resumes",
        "状态信息": "Status Information",
        "选择菜单栏下拉面板中显示的系统与电池信息。": "Choose the system and battery information shown in the menu panel.",
        "电源来源": "Power Source",
        "剩余使用时间": "Time Remaining",
        "系统运行时间": "System Uptime",
        "电池工作模式": "Battery Mode",
        "电池健康": "Battery Health",
        "查看电池老化、使用次数和当前温度。": "View battery aging, cycle count, and current temperature.",
        "循环次数": "Cycle Count",
        "电池健康度": "Battery Health",
        "容量与寿命趋势": "Capacity & Health Trend",
        "当前容量": "Current Capacity",
        "估算满充": "Estimated Full",
        "设计容量": "Design Capacity",
        "正在积累容量历史…": "Building capacity history…",
        "每日记录 · 今天开始": "Daily tracking · Starts today",
        "充电器规格": "Charger Specifications",
        "电池温度": "Battery Temperature",
        "显示电池与电源适配器的电压、电流和功率。": "Show battery and power adapter voltage, current, and power.",
        "电池功率数据": "Battery Power Data",
        "适配器功率数据": "Adapter Power Data",
        "彩色能量流": "Color Energy Flow",
        "用立体流向图展示电源、电池和电脑之间的能量分配。": "Visualize energy distribution between the adapter, battery, and Mac.",
        "显示功率分配图": "Show Power Flow Diagram",
        "计划任务": "Scheduled Tasks",
        "按设定时间自动调整上限、补电、校准、暂停或放电。错过的任务可在 Mac 唤醒后补做。": "Automatically adjust the limit, top up, calibrate, pause, or discharge on schedule. Missed tasks can run after your Mac wakes.",
        "还没有计划任务": "No Scheduled Tasks",
        "创建一项任务，让 Aidente 在合适的时间自动照顾电池。": "Create a task so Aidente can care for your battery at the right time.",
        "删除任务": "Delete Task",
        "添加计划任务": "Add Scheduled Task",
        "Apple 快捷指令": "Apple Shortcuts",
        "在“快捷指令”中使用“打开 URL”操作，即可控制 Aidente。": "Use the Open URL action in Shortcuts to control Aidente.",
        "选择动作、执行时间和重复规则": "Choose an action, time, and repeat rule",
        "任务设置": "Task Settings",
        "执行动作": "Action",
        "充电上限": "Charge Limit",
        "放电目标": "Discharge Target",
        "首次执行": "First Run",
        "重复": "Repeat",
        "错过后尽快补做": "Run Soon After a Miss",
        "Mac 唤醒并运行 Aidente 后执行": "Run after the Mac wakes and Aidente is active",
        "取消": "Cancel",
        "添加任务": "Add Task",
        "设置充电上限": "Set Charge Limit",
        "开始电池校准": "Start Battery Calibration",
        "临时充至 100%": "Top Up to 100%",
        "暂停充电": "Pause Charging",
        "放电至": "Discharge To",
        "仅一次": "Once",
        "每天": "Daily",
        "工作日": "Weekdays",
        "每周": "Weekly",
        "每两周": "Every Two Weeks",
        "每月": "Monthly",
        "电量读取方式": "Battery Level Source",
        "选择 Aidente 用于充电上限、巡航和校准的电量数据。": "Choose the battery level Aidente uses for charge limits, sailing, and calibration.",
        "使用硬件电量百分比": "Use Hardware Battery Percentage",
        "直接读取电池管理系统的原始数值，而不是 macOS 校准后的显示值": "Read the raw battery management value instead of the macOS-calibrated percentage",
        "硬件电量通常会与菜单栏中的 macOS 电量相差几个百分点。切换后，所有充电策略都将使用所选读数。": "The hardware value may differ from the macOS menu bar by a few points. All charging strategies use the selected reading.",
        "问题记录": "Issue Recording",
        "复现异常时记录关键电池与充电控制状态，最长持续两小时。": "Record key battery and charging-control states while reproducing an issue, for up to two hours.",
        "问题编号": "Support ID",
        "复制编号": "Copy ID",
        "导出诊断包": "Export Diagnostics",
        "只在你确认后生成本地 ZIP，Aidente 不会自动上传。": "Create a local ZIP only after your confirmation. Aidente never uploads it automatically.",
        "包含最近的崩溃报告": "Include Recent Crash Reports",
        "最多收集最近七天内的 5 份 Aidente 报告，并自动脱敏": "Collect up to five Aidente reports from the last seven days and redact them automatically",
        "包含耗电 App 名称": "Include Energy App Names",
        "默认关闭；开启后仅记录导出时的 App 名称与活动估算": "Off by default; when enabled, includes app names and activity estimates at export time",
        "导出内容预览": "Export Preview",
        "Aidente 统一日志（最近 1 小时或本次记录）": "Aidente unified logs (last hour or current recording)",
        "软件、macOS、机型与后台服务状态": "App, macOS, Mac model, and helper status",
        "电池、适配器及充电控制快照": "Battery, adapter, and charging-control snapshot",
        "经过筛选的充电设置，不包含完整偏好数据": "Selected charging settings, not the complete preferences domain",
        "用户名、路径、网络地址、序列号自动脱敏": "User names, paths, network addresses, and serial numbers are redacted",
        "在访达中显示": "Show in Finder",
        "隐私保护": "Privacy Protection",
        "诊断信息始终由用户决定是否生成和发送。": "You always decide whether diagnostic information is generated or shared.",
        "Aidente 不会自动上传日志。诊断包默认不含耗电 App 名称，也不主动收集账户名、设备序列号或网络配置。发送前可以先解压检查。": "Aidente never uploads logs automatically. Energy app names are excluded by default, and account names, device serial numbers, and network configuration are not intentionally collected. You can inspect the archive before sharing it.",
        "可选 CLI": "Optional CLI",
        "高级用户可以从终端查看状态或触发操作，CLI 不会常驻后台。": "Advanced users can inspect status or trigger actions from Terminal. The CLI never stays resident.",
        "复制 CLI 完整路径": "Copy Full CLI Path",
        "为 Apple 芯片 MacBook 打造的独立电池养护工具": "An independent battery care utility for Apple silicon MacBooks",
        "电池养护 · 充电管理 · 实时监测": "Battery Care · Charging Control · Live Monitoring",
        "安全说明": "Safety",
        "底层控制始终以设备能力检测和明确授权为前提。": "Low-level control always requires capability checks and explicit authorization.",
        "Aidente 会调整底层电池充电控制。设备不支持某项能力时，软件会自动退回只读监测模式。你可以随时关闭“管理充电”，恢复系统默认充电状态。": "Aidente adjusts low-level battery charging controls. If a capability is unavailable, it falls back to read-only monitoring. Turn off Manage Charging at any time to restore the system default.",
        "开放源代码": "Open Source",
        "许可文本和第三方声明均随应用一同提供。": "License text and third-party notices are included with the app.",
        "Aidente 是基于开源 Stasis 项目修改的 GPL-3.0 软件，并使用 SMCKit 与 Defaults 开源组件。": "Aidente is GPL-3.0 software based on the open-source Stasis project and uses SMCKit and Defaults.",
        "查看开源许可证": "View Open-Source Licenses",
        "商标声明": "Trademark Notice",
        "独立开发，不包含其他商业软件的代码或授权机制。": "Independently developed without code or licensing mechanisms from other commercial software.",
        "Aidente 是独立项目，与 AppHouseKitchen 不存在隶属、授权或分发关系。AlDente 是其各自权利人的商标。": "Aidente is an independent project and is not affiliated with, authorized by, or distributed by AppHouseKitchen. AlDente is a trademark of its respective owner.",
        "只读监测": "Read-Only Monitoring",
        "正在充电": "Charging",
        "充电已暂停": "Charging Paused",
        "巡航中": "Sailing",
        "高温保护": "Heat Protection",
        "睡眠保护": "Sleep Protection",
        "充电控制未生效": "Charging Control Inactive",
        "电池": "Battery",
        "电源适配器": "Power Adapter",
        "电池与电源适配器": "Battery & Power Adapter",
        "未在充电": "Not Charging",
        "正在估算…": "Estimating…",
        "已接通电源（未充电）": "Plugged In (Not Charging)",
        "正在使用电池": "On Battery",
        "未知": "Unknown",
        "电源已连接": "Power Connected",
        "实时功率分流": "Live Power Flow",
        "当前耗电 App": "Top Energy Apps",
        "按处理器活动实时估算": "Estimated live from processor activity",
        "正在采样当前应用活动…": "Sampling current app activity…",
        "当前没有检测到明显耗电的前台应用": "No significant foreground app activity detected",
        "快捷养护": "Quick Care",
        "当前已暂停，点击恢复管理": "Currently paused; click to resume management",
        "保持适配器供电，停止电池充入": "Keep adapter power while stopping battery charging",
        "放电至充电上限": "Discharge to Charge Limit",
        "执行完整充放电校准流程": "Run a complete charge and discharge calibration",
        "自动保护": "Automatic Protection",
        "高温": "Heat",
        "睡眠暂停": "Sleep Pause",
        "巡航": "Sailing",
        "电池详情": "Battery Details",
        "充电设置": "Charging Settings",
        "实时电池养护": "Live Battery Care",
        "上限": "Limit",
        "拖动白色标记调整上限": "Drag the white marker to adjust the limit",
        "适配器": "Adapter",
        "电池充入": "Battery Input",
        "系统使用": "System Use",
        "电池输出": "Battery Output",
        "开启": "On",
        "关闭": "Off",
        "开": "On",
        "关": "Off",
        "管理充电": "Manage Charging",
        "限制最高充电量，减少电池长期处于满电状态的时间。": "Limit the maximum charge to reduce time spent at full battery.",
        "需要在系统设置中批准 Aidente 后台控制服务": "Approve the Aidente background control service in System Settings",
        "重新检查授权": "Check Authorization Again",
        "请前往“系统设置 → 通用 → 登录项与扩展”批准 Aidente，然后返回这里重新检查。": "Open System Settings → General → Login Items & Extensions, approve Aidente, then return here and check again.",
        "当前正从安装磁盘映像运行，后台控制服务无法可靠启动。请退出 Aidente，将应用拖入“应用程序”文件夹后重新打开。": "Aidente is running from a disk image, so its background service cannot start reliably. Quit the app, drag it to Applications, and reopen it.",
        "当前设备不支持充电管理；Aidente 将继续提供只读电池监测。": "This device does not support charging control; Aidente will continue in read-only monitoring mode.",
        "达到上限后暂停充电": "Pause charging at the limit",
        "快捷操作": "Quick Actions",
        "执行一次性操作，不会改动你保存的充电上限。": "Run a one-time action without changing your saved charge limit.",
        "当前状态": "Current Status",
        "修复控制服务": "Repair Control Service",
        "停止补电": "Stop Top-Up",
        "开始校准": "Start Calibration",
        "取消校准": "Cancel Calibration",
        "恢复充电": "Resume Charging",
        "自动放电": "Automatic Discharge",
        "接通电源且电量高于目标时，自动放电至充电上限。": "When plugged in above the target, automatically discharge to the charge limit.",
        "启用自动放电": "Enable Automatic Discharge",
        "到达目标后自动恢复适配器供电": "Restore adapter power automatically at the target",
        "当前设备不支持适配器控制。": "This device does not support adapter control.",
        "睡眠与退出行为": "Sleep & Quit Behavior",
        "决定 Mac 睡眠以及 Aidente 未运行时如何保持充电状态。": "Choose charging behavior while the Mac sleeps or Aidente is not running.",
        "达到上限前阻止睡眠": "Prevent Sleep Until Charge Limit",
        "睡眠时暂停充电": "Pause Charging During Sleep",
        "退出 Aidente 后保持暂停": "Keep Charging Paused After Quitting",
        "适合快速用户切换或临时退出应用": "Useful for fast user switching or temporarily quitting the app",
        "电池校准": "Battery Calibration",
        "充至 100% → 放电 → 再充满 → 满电保持 → 恢复原上限。": "Charge to 100% → discharge → recharge → hold full → restore the original limit.",
        "满电保持时间": "Full-Charge Hold Time",
        "巡航模式": "Sailing Mode",
        "允许电量在上限附近自然浮动，减少频繁微量补电。": "Let battery level float near the limit to reduce frequent top-ups.",
        "启用巡航模式": "Enable Sailing Mode",
        "低于上限多少时恢复充电": "Resume Charging Below Limit By",
        "恢复充电电量": "Resume Charging Level",
        "温度超过阈值时暂停充电，并通过五分钟迟滞避免频繁切换。": "Pause charging above the temperature threshold with a five-minute hysteresis.",
        "启用高温保护": "Enable Heat Protection",
        "温度上限": "Temperature Limit",
        "MagSafe 指示灯": "MagSafe LED",
        "在受支持机型上用颜色显示充电、暂停和保护状态。": "Show charging, pause, and protection states with colors on supported models.",
        "由 Aidente 控制指示灯": "Let Aidente Control the LED",
        "高温保护时的灯光": "LED During Heat Protection",
        "绿色": "Green",
        "橙色": "Orange",
        "橙色慢闪": "Slow Blinking Orange",
        "橙色快闪": "Fast Blinking Orange",
        "当前设备不支持 MagSafe 指示灯控制。": "This device does not support MagSafe LED control.",
        "无法启用充电控制服务": "Unable to Enable Charging Control",
        "好": "OK",
        "设置…": "Settings…",
        "退出 Aidente": "Quit Aidente",
        "Aidente 状态": "Aidente Status",
        "剩余时间": "Time Remaining",
        "电池模式": "Battery Mode",
        "电池功率": "Battery Power",
        "适配器功率": "Adapter Power",
        "电池仪表盘": "Battery Dashboard",
    ]
}
