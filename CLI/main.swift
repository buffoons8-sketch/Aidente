import Foundation

private enum CLIError: LocalizedError {
    case invalidCommand
    case invalidValue(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCommand:
            "未知命令。使用 aidente help 查看帮助。"
        case .invalidValue(let message):
            message
        case .commandFailed(let command):
            "命令执行失败：\(command)"
        }
    }
}

@discardableResult
private func run(
    executable: String,
    arguments: [String],
    captureOutput: Bool = false
) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let pipe = Pipe()
    if captureOutput {
        process.standardOutput = pipe
        process.standardError = pipe
    }

    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw CLIError.commandFailed(([executable] + arguments).joined(separator: " "))
    }

    guard captureOutput else { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}

private func openAidenteURL(_ value: String) throws {
    try run(executable: "/usr/bin/open", arguments: ["-g", value])
}

private func printStatus() throws {
    let domain = UserDefaults.standard.persistentDomain(forName: "com.aidente.app") ?? [:]
    let limit = domain["chargeLimit"] as? Int ?? 80
    let managesCharging = domain["manageCharging"] as? Bool ?? false
    let paused = domain["manualPauseActive"] as? Bool ?? false
    let battery = try run(
        executable: "/usr/bin/pmset",
        arguments: ["-g", "batt"],
        captureOutput: true
    ).trimmingCharacters(in: .whitespacesAndNewlines)

    print("Aidente")
    print("  Manage charging: \(managesCharging ? "on" : "off")")
    print("  Charge limit: \(limit)%")
    print("  Manual pause: \(paused ? "on" : "off")")
    print("")
    print(battery)
}

private func printHelp() {
    print(
        """
        Aidente CLI（按需运行，不会常驻后台）

        用法：
          aidente status                 查看电池与充电设置
          aidente limit <20...100>       设置充电上限
          aidente pause                  暂停充电
          aidente resume                 恢复正常管理
          aidente top-up                 临时充至 100%
          aidente discharge [20...100]   开始放电，可选目标电量
          aidente calibrate              开始电池校准
          aidente dashboard              打开独立主菜单
          aidente diagnostics            打开诊断中心
          aidente help                   显示帮助

        控制命令会通过 Aidente 的 URL 接口交给图形应用执行。
        """
    )
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let command = arguments.first?.lowercased() ?? "help"

    switch command {
    case "help", "--help", "-h":
        printHelp()
    case "status":
        try printStatus()
    case "limit":
        guard arguments.count >= 2,
              let value = Int(arguments[1]),
              (20...100).contains(value) else {
            throw CLIError.invalidValue("充电上限必须是 20 到 100 之间的整数。")
        }
        try openAidenteURL("aidente://set-limit?value=\(value)")
        print("已请求将充电上限设为 \(value)%")
    case "pause":
        try openAidenteURL("aidente://pause")
        print("已请求暂停充电")
    case "resume":
        try openAidenteURL("aidente://resume")
        print("已请求恢复正常管理")
    case "top-up", "topup":
        try openAidenteURL("aidente://top-up")
        print("已请求临时充至 100%")
    case "discharge":
        if arguments.count >= 2 {
            guard let value = Int(arguments[1]), (20...100).contains(value) else {
                throw CLIError.invalidValue("放电目标必须是 20 到 100 之间的整数。")
            }
            try openAidenteURL("aidente://discharge?value=\(value)")
            print("已请求放电至 \(value)%")
        } else {
            try openAidenteURL("aidente://discharge")
            print("已请求放电至当前充电上限")
        }
    case "calibrate":
        try openAidenteURL("aidente://calibrate")
        print("已请求开始电池校准")
    case "dashboard", "menu":
        try openAidenteURL("aidente://dashboard")
        print("已打开 Aidente 主菜单")
    case "diagnostics", "diagnostic", "logs":
        try openAidenteURL("aidente://settings?tab=diagnostics")
        print("已打开 Aidente 诊断中心")
    default:
        throw CLIError.invalidCommand
    }
} catch {
    FileHandle.standardError.write(
        Data("错误：\(error.localizedDescription)\n".utf8)
    )
    exit(1)
}
