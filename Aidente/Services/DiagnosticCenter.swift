import AppKit
import Darwin
import Defaults
import Foundation
import Observation
import UniformTypeIdentifiers
import os.log

private struct DiagnosticExportInputs: Sendable {
    let supportIdentifier: String
    let logWindowMinutes: Int
    let systemReport: String
    let batteryReport: String
    let preferencesReport: String
    let energyReport: String?
    let includeCrashReports: Bool
    let destinationURL: URL
}

private enum DiagnosticExportError: LocalizedError {
    case commandFailed(String)
    case packageFailed

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command):
            "诊断命令执行失败：\(command)"
        case .packageFailed:
            "无法生成诊断压缩包"
        }
    }
}

@MainActor
@Observable
final class DiagnosticCenter {
    private static let maximumSessionDuration: TimeInterval = 2 * 60 * 60

    private let batteryService: BatteryService
    private let chargeManager: ChargeManager
    private let logger = Logger(
        subsystem: "com.aidente.app",
        category: "Diagnostics"
    )

    private var recordingTask: Task<Void, Never>?

    private(set) var recordingStartedAt: Date?
    private(set) var isExporting = false
    private(set) var lastExportURL: URL?
    private(set) var statusMessage: String?
    private(set) var errorMessage: String?

    var includeCrashReports = true
    var includeEnergyAppNames = false

    var isRecording: Bool { recordingStartedAt != nil }

    var supportIdentifier: String {
        let identifier = Defaults[.diagnosticSessionID]
        return identifier.isEmpty ? AidenteL10n.t("尚未生成", "Not generated") : identifier
    }

    init(batteryService: BatteryService, chargeManager: ChargeManager) {
        self.batteryService = batteryService
        self.chargeManager = chargeManager
        restoreRecordingSession()
    }

    func startRecording() {
        guard !isRecording else { return }

        let startedAt = Date()
        let identifier = makeSupportIdentifier()
        recordingStartedAt = startedAt
        Defaults[.diagnosticSessionStartedAt] = startedAt.timeIntervalSince1970
        Defaults[.diagnosticSessionID] = identifier
        errorMessage = nil
        statusMessage = AidenteL10n.t(
            "问题记录已开始，请复现问题后导出诊断包。",
            "Recording started. Reproduce the issue, then export the diagnostic package."
        )
        logger.notice(
            "DIAGNOSTIC_SESSION_BEGIN id=\(identifier, privacy: .public)"
        )
        startRecordingTask()
    }

    func stopRecording() {
        guard let recordingStartedAt else { return }

        let identifier = Defaults[.diagnosticSessionID]
        let duration = Int(Date().timeIntervalSince(recordingStartedAt))
        logger.notice(
            "DIAGNOSTIC_SESSION_END id=\(identifier, privacy: .public) durationSeconds=\(duration, privacy: .public)"
        )
        recordingTask?.cancel()
        recordingTask = nil
        self.recordingStartedAt = nil
        Defaults[.diagnosticSessionStartedAt] = 0
        statusMessage = AidenteL10n.t(
            "问题记录已停止，仍可导出最近一小时的诊断信息。",
            "Recording stopped. You can still export diagnostics from the last hour."
        )
    }

    func exportDiagnostics() async {
        guard !isExporting else { return }
        ensureSupportIdentifier()

        let panel = NSSavePanel()
        panel.title = AidenteL10n.t("导出 Aidente 诊断包", "Export Aidente Diagnostics")
        panel.nameFieldStringValue = suggestedPackageName()
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        isExporting = true
        errorMessage = nil
        statusMessage = AidenteL10n.t(
            "正在收集并脱敏诊断信息…",
            "Collecting and redacting diagnostic information…"
        )

        let inputs = await makeExportInputs(destinationURL: destinationURL)

        do {
            let exportedURL = try await Task.detached(priority: .utility) {
                try Self.createDiagnosticPackage(inputs: inputs)
            }.value
            lastExportURL = exportedURL
            statusMessage = AidenteL10n.t(
                "诊断包已导出。发送前仍可解压检查内容。",
                "Diagnostics exported. You can inspect the archive before sending it."
            )
            logger.notice(
                "DIAGNOSTIC_PACKAGE_EXPORTED id=\(inputs.supportIdentifier, privacy: .public)"
            )
        } catch {
            errorMessage = Self.sanitize(error.localizedDescription)
            statusMessage = nil
            logger.error(
                "Diagnostic export failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        isExporting = false
    }

    func revealLastExport() {
        guard let lastExportURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastExportURL])
    }

    func copySupportIdentifier() {
        let identifier = supportIdentifier
        guard identifier != AidenteL10n.t("尚未生成", "Not generated") else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(identifier, forType: .string)
        statusMessage = AidenteL10n.t(
            "问题编号已复制。",
            "Support ID copied."
        )
    }

    func copyCLIPath() {
        let path = Bundle.main.url(forResource: "aidente", withExtension: nil)?.path
            ?? "/Applications/Aidente.app/Contents/Resources/aidente"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        statusMessage = AidenteL10n.t(
            "CLI 路径已复制。",
            "CLI path copied."
        )
    }

    func stop() {
        recordingTask?.cancel()
        recordingTask = nil
    }

    private func restoreRecordingSession() {
        let timestamp = Defaults[.diagnosticSessionStartedAt]
        guard timestamp > 0 else { return }

        let startedAt = Date(timeIntervalSince1970: timestamp)
        let elapsed = Date().timeIntervalSince(startedAt)
        guard elapsed >= 0, elapsed < Self.maximumSessionDuration else {
            Defaults[.diagnosticSessionStartedAt] = 0
            Defaults[.diagnosticSessionID] = ""
            return
        }

        recordingStartedAt = startedAt
        logger.notice(
            "DIAGNOSTIC_SESSION_RESUMED id=\(Defaults[.diagnosticSessionID], privacy: .public)"
        )
        startRecordingTask()
    }

    private func startRecordingTask() {
        recordingTask?.cancel()
        logCurrentSnapshot()

        recordingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled, let self else { return }
                guard let startedAt = self.recordingStartedAt else { return }

                if Date().timeIntervalSince(startedAt) >= Self.maximumSessionDuration {
                    self.stopRecording()
                    self.statusMessage = AidenteL10n.t(
                        "问题记录已在两小时后自动停止。",
                        "Recording stopped automatically after two hours."
                    )
                    return
                }

                self.logCurrentSnapshot()
            }
        }
    }

    private func logCurrentSnapshot() {
        let metrics = batteryService.metrics
        let adapter = batteryService.adapterMetrics
        let chargeLimit = Defaults[.chargeLimit]
        let manageCharging = Defaults[.manageCharging]
        let manualPause = chargeManager.manualPauseActive
        let hasControlError = chargeManager.controlError != nil

        logger.notice(
            "DIAGNOSTIC_SNAPSHOT battery=\(metrics.batteryPercentage, privacy: .public) hardwareBattery=\(metrics.hardwareBatteryPercentage, privacy: .public) health=\(metrics.batteryHealth, privacy: .public) currentCapacity=\(metrics.currentCapacityMilliampHours, privacy: .public) estimatedFullCapacity=\(metrics.estimatedFullChargeCapacityMilliampHours, privacy: .public) designCapacity=\(metrics.designCapacityMilliampHours, privacy: .public) charging=\(metrics.isCharging, privacy: .public) adapterConnected=\(adapter.adapterConnected, privacy: .public) batteryPower=\(metrics.batteryPower, privacy: .public) adapterPower=\(adapter.adapterPower, privacy: .public) adapterMaximumPower=\(adapter.maximumSupportedPower, privacy: .public) temperature=\(metrics.batteryTemperature, privacy: .public) chargeLimit=\(chargeLimit, privacy: .public) manageCharging=\(manageCharging, privacy: .public) manualPause=\(manualPause, privacy: .public) controlError=\(hasControlError, privacy: .public)"
        )
    }

    private func ensureSupportIdentifier() {
        if Defaults[.diagnosticSessionID].isEmpty {
            Defaults[.diagnosticSessionID] = makeSupportIdentifier()
        }
    }

    private func makeSupportIdentifier() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let suffix = UUID().uuidString.prefix(8).uppercased()
        return "AID-\(formatter.string(from: Date()))-\(suffix)"
    }

    private func suggestedPackageName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "Aidente-Diagnostics-\(formatter.string(from: Date())).zip"
    }

    private func makeExportInputs(destinationURL: URL) async -> DiagnosticExportInputs {
        let start = recordingStartedAt
        let elapsedMinutes = start.map {
            Int(ceil(Date().timeIntervalSince($0) / 60))
        } ?? 60
        let logWindowMinutes = min(max(elapsedMinutes, 5), 120)

        let energyReport: String?
        if includeEnergyAppNames {
            let snapshots = await Task.detached(priority: .utility) {
                AppEnergyUsageService.readTopApps(limit: 10)
            }.value
            energyReport = snapshots.enumerated().map { index, snapshot in
                "\(index + 1). \(snapshot.name) | CPU estimate: \(String(format: "%.2f", snapshot.cpuUsage))%"
            }.joined(separator: "\n")
        } else {
            energyReport = nil
        }

        return DiagnosticExportInputs(
            supportIdentifier: Defaults[.diagnosticSessionID],
            logWindowMinutes: logWindowMinutes,
            systemReport: makeSystemReport(),
            batteryReport: makeBatteryReport(),
            preferencesReport: makePreferencesReport(),
            energyReport: energyReport,
            includeCrashReports: includeCrashReports,
            destinationURL: destinationURL
        )
    }

    private func makeSystemReport() -> String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "development"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "development"
        let capabilities = batteryService.deviceCapabilities
        let helper = ChargingHelperManager.shared
        helper.refreshStatus()

        let helperStatus: String
        switch helper.helperStatus {
        case .notInstalled: helperStatus = "notInstalled"
        case .requiresApproval: helperStatus = "requiresApproval"
        case .installed: helperStatus = "installed"
        }

        return """
        Support ID: \(Defaults[.diagnosticSessionID])
        Exported at: \(ISO8601DateFormatter().string(from: Date()))
        Aidente version: \(version) (\(build))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Hardware model: \(hardwareModel())
        Architecture: arm64
        UI language: \(Defaults[.appLanguage].rawValue)
        Helper status: \(helperStatus)
        Helper registration error present: \(helper.registrationError != nil)
        Charging control capability: \(capabilities.chargingControl)
        Adapter control capability: \(capabilities.adapterControl)
        MagSafe present: \(capabilities.hasMagSafe)
        MagSafe LED control capability: \(capabilities.magsafeLEDControl)

        Serial number, account name, network configuration, and full preference data are not collected.
        """
    }

    private func makeBatteryReport() -> String {
        let metrics = batteryService.metrics
        let adapter = batteryService.adapterMetrics
        let report: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "battery": [
                "displayedPercentage": metrics.batteryPercentage,
                "hardwarePercentage": metrics.hardwareBatteryPercentage,
                "isCharging": metrics.isCharging,
                "timeRemainingMinutes": metrics.timeRemaining,
                "voltage": metrics.batteryVoltage,
                "current": metrics.batteryCurrent,
                "power": metrics.batteryPower,
                "temperatureCelsius": metrics.batteryTemperature,
                "healthPercentage": metrics.batteryHealth,
                "cycleCount": metrics.cycleCount,
                "currentCapacityMilliampHours": metrics.currentCapacityMilliampHours,
                "estimatedFullChargeCapacityMilliampHours":
                    metrics.estimatedFullChargeCapacityMilliampHours,
                "designCapacityMilliampHours": metrics.designCapacityMilliampHours,
                "externalConnected": metrics.externalConnected,
            ],
            "adapter": [
                "connected": adapter.adapterConnected,
                "voltage": adapter.adapterVoltage,
                "current": adapter.adapterCurrent,
                "power": adapter.adapterPower,
                "maximumSupportedPower": adapter.maximumSupportedPower,
                "protocol": adapter.protocolName,
                "powerProfiles": adapter.powerProfiles.map { profile in
                    [
                        "voltage": profile.voltage,
                        "current": profile.current,
                        "power": profile.power,
                        "active": profile.isActive,
                    ]
                },
            ],
            "chargingControl": [
                "operation": chargeManager.operationStatusTitle,
                "manualPauseActive": chargeManager.manualPauseActive,
                "topUpActive": chargeManager.topUpActive,
                "forceDischargeActive": chargeManager.forceDischargeActive,
                "calibrationStage": chargeManager.calibrationStage.rawValue,
                "hasControlError": chargeManager.controlError != nil,
                "controlError": chargeManager.controlError ?? "",
            ],
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return "Unable to encode battery snapshot."
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func makePreferencesReport() -> String {
        let preferences: [String: Any] = [
            "manageCharging": Defaults[.manageCharging],
            "chargeLimit": Defaults[.chargeLimit],
            "sailingMode": Defaults[.sailingMode],
            "sailingModeLimit": Defaults[.sailingModeLimit],
            "automaticDischarge": Defaults[.automaticDischarge],
            "heatProtection": Defaults[.enableHeatProtectionMode],
            "heatProtectionLimit": Defaults[.heatProtectionLimit],
            "pauseDuringSleep": Defaults[.stopChargingWhileSleeping],
            "keepPausedAfterQuit": Defaults[.stopChargingWhenAppClosed],
            "useHardwarePercentage": Defaults[.useHardwarePercentage],
            "interfaceMaterial": Defaults[.interfaceMaterialStyle].rawValue,
            "launchAtLogin": Defaults[.launchAtLogin],
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: preferences,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return "Unable to encode selected preferences."
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func hardwareModel() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
            return "Unknown Apple Silicon Mac"
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else {
            return "Unknown Apple Silicon Mac"
        }
        return String(cString: buffer)
    }

    private nonisolated static func createDiagnosticPackage(
        inputs: DiagnosticExportInputs
    ) throws -> URL {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(
            "Aidente-Diagnostics-\(UUID().uuidString)",
            isDirectory: true
        )
        let packageDirectory = temporaryRoot.appendingPathComponent(
            "Aidente-Diagnostics-\(inputs.supportIdentifier)",
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try fileManager.createDirectory(
            at: packageDirectory,
            withIntermediateDirectories: true
        )

        let crashCount = inputs.includeCrashReports
            ? try collectCrashReports(into: packageDirectory)
            : 0
        try collectUnifiedLogs(
            minutes: inputs.logWindowMinutes,
            destination: packageDirectory.appendingPathComponent("aidente-unified.log")
        )
        try writeText(
            inputs.systemReport,
            to: packageDirectory.appendingPathComponent("system.txt")
        )
        try writeText(
            inputs.batteryReport,
            to: packageDirectory.appendingPathComponent("battery-and-control.json")
        )
        try writeText(
            inputs.preferencesReport,
            to: packageDirectory.appendingPathComponent("selected-preferences.json")
        )
        if let energyReport = inputs.energyReport {
            try writeText(
                energyReport,
                to: packageDirectory.appendingPathComponent("energy-apps.txt")
            )
        }

        let manifest = """
        Aidente Diagnostic Package
        Support ID: \(inputs.supportIdentifier)

        Included:
        - Aidente unified logs from the last \(inputs.logWindowMinutes) minute(s)
        - App, macOS, hardware-model, helper, and capability summary
        - Current battery, adapter, and charging-control snapshot
        - Selected charging preferences only
        - Crash reports: \(crashCount)
        - Energy app names: \(inputs.energyReport == nil ? "not included" : "included by user choice")

        Privacy:
        - The package is created locally and is never uploaded automatically.
        - User-home paths, volume names, IP addresses, MAC addresses, UUIDs, and labeled serial numbers are redacted.
        - Account names, full preference data, network configuration, and device serial numbers are not intentionally collected.
        - Please inspect this archive before sharing it.
        """
        try writeText(
            manifest,
            to: packageDirectory.appendingPathComponent("README.txt")
        )

        let temporaryZip = temporaryRoot.appendingPathComponent("Aidente-Diagnostics.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--sequesterRsrc", "--keepParent",
            packageDirectory.path,
            temporaryZip.path,
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              fileManager.fileExists(atPath: temporaryZip.path) else {
            throw DiagnosticExportError.packageFailed
        }

        if fileManager.fileExists(atPath: inputs.destinationURL.path) {
            try fileManager.removeItem(at: inputs.destinationURL)
        }
        try fileManager.moveItem(at: temporaryZip, to: inputs.destinationURL)
        return inputs.destinationURL
    }

    private nonisolated static func collectUnifiedLogs(
        minutes: Int,
        destination: URL
    ) throws {
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "show",
            "--last", "\(minutes)m",
            "--style", "compact",
            "--info",
            "--debug",
            "--predicate", "subsystem BEGINSWITH \"com.aidente.app\"",
        ]
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DiagnosticExportError.commandFailed("log show")
        }

        try? handle.synchronize()
        let text = try String(contentsOf: destination, encoding: .utf8)
        try sanitize(text).write(to: destination, atomically: true, encoding: .utf8)
    }

    private nonisolated static func collectCrashReports(into directory: URL) throws -> Int {
        let crashDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: crashDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let candidates = files.compactMap { url -> (URL, Date)? in
            let name = url.lastPathComponent.lowercased()
            guard name.hasPrefix("aidente"),
                  name.hasSuffix(".ips") || name.hasSuffix(".crash") else {
                return nil
            }
            guard let values = try? url.resourceValues(
                forKeys: [.contentModificationDateKey, .fileSizeKey]
            ), let modified = values.contentModificationDate,
                  modified >= cutoff else {
                return nil
            }
            return (url, modified)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(5)

        var count = 0
        for candidate in candidates {
            let handle = try FileHandle(forReadingFrom: candidate.0)
            let data = try handle.read(upToCount: 1_500_000) ?? Data()
            try? handle.close()
            let text = String(decoding: data, as: UTF8.self)
            let destination = directory.appendingPathComponent("crash-\(count + 1).txt")
            try writeText(text, to: destination)
            count += 1
        }
        return count
    }

    private nonisolated static func writeText(_ text: String, to url: URL) throws {
        try sanitize(text).write(to: url, atomically: true, encoding: .utf8)
    }

    nonisolated static func sanitize(_ input: String) -> String {
        var text = input
        let replacements: [(String, String)] = [
            (#"/Users/[^/\s]+"#, "<USER_HOME>"),
            (#"/Volumes/[^/\s]+"#, "<VOLUME>"),
            (#"\b(?:\d{1,3}\.){3}\d{1,3}\b"#, "<IP_ADDRESS>"),
            (#"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b"#, "<MAC_ADDRESS>"),
            (#"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b"#, "<UUID>"),
            (#"(?i)(serial(?: number)?\s*[:=]\s*)[^\s,;]+"#, "$1<SERIAL_REDACTED>"),
        ]

        for (pattern, replacement) in replacements {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = expression.stringByReplacingMatches(
                in: text,
                range: range,
                withTemplate: replacement
            )
        }
        return text
    }
}
