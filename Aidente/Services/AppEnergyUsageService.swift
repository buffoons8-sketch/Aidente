import AppKit
import Foundation

struct AppEnergyUsageSnapshot: Identifiable, Sendable {
    let bundlePath: String
    let name: String
    let cpuUsage: Double

    var id: String { bundlePath }
}

enum AppEnergyUsageService {
    static func readTopApps(limit: Int = 4) -> [AppEnergyUsageSnapshot] {
        let process = Process()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-wwaxo", "pid=,%cpu=,comm="]
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["LC_ALL": "C"]
        ) { _, newValue in newValue }
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return []
        }

        let text = String(decoding: data, as: UTF8.self)
        var totals: [String: (name: String, cpuUsage: Double)] = [:]

        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(
                maxSplits: 2,
                whereSeparator: \.isWhitespace
            )
            guard fields.count == 3,
                let processIdentifier = pid_t(fields[0]),
                let cpuUsage = Double(fields[1]),
                cpuUsage > 0,
                let app = appIdentity(
                    processIdentifier: processIdentifier,
                    command: String(fields[2])
                ),
                app.bundleIdentifier != Bundle.main.bundleIdentifier
            else {
                continue
            }

            let current = totals[app.bundlePath]?.cpuUsage ?? 0
            totals[app.bundlePath] = (app.name, current + cpuUsage)
        }

        return totals
            .map {
                AppEnergyUsageSnapshot(
                    bundlePath: $0.key,
                    name: $0.value.name,
                    cpuUsage: $0.value.cpuUsage
                )
            }
            .sorted {
                if $0.cpuUsage == $1.cpuUsage {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.cpuUsage > $1.cpuUsage
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    private static func appIdentity(
        processIdentifier: pid_t,
        command: String
    ) -> (
        bundlePath: String,
        name: String,
        bundleIdentifier: String?
    )? {
        let runningApplication = NSRunningApplication(
            processIdentifier: processIdentifier
        )
        let applicationURL =
            runningApplication?.bundleURL.flatMap(outermostApplicationURL)
            ?? applicationURL(fromCommand: command)
        guard let applicationURL else {
            return nil
        }

        let bundle = Bundle(url: applicationURL)
        let candidates = [
            bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.localizedInfoDictionary?["CFBundleName"] as? String,
            bundle?.infoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.infoDictionary?["CFBundleName"] as? String,
            FileManager.default.displayName(atPath: applicationURL.path),
            applicationURL.deletingPathExtension().lastPathComponent,
        ]
        guard let name = candidates.compactMap(sanitizedDisplayName).first else {
            return nil
        }

        return (
            applicationURL.path,
            name,
            bundle?.bundleIdentifier ?? runningApplication?.bundleIdentifier
        )
    }

    private static func applicationURL(fromCommand command: String) -> URL? {
        guard !command.contains("\u{FFFD}") else { return nil }
        return outermostApplicationURL(
            containing: URL(fileURLWithPath: command)
        )
    }

    private static func outermostApplicationURL(containing url: URL) -> URL? {
        let components = url.standardizedFileURL.pathComponents
        var path = ""

        for component in components {
            if component == "/" {
                path = "/"
                continue
            }
            path = URL(fileURLWithPath: path)
                .appendingPathComponent(component)
                .path
            if component.lowercased().hasSuffix(".app") {
                return URL(fileURLWithPath: path).standardizedFileURL
            }
        }

        return nil
    }

    private static func sanitizedDisplayName(_ candidate: String?) -> String? {
        guard let candidate else { return nil }

        let name = candidate
            .replacingOccurrences(of: "\u{FFFD}", with: "")
            .components(separatedBy: .controlCharacters)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
        let visibleName = name.hasSuffix(".app")
            ? String(name.dropLast(4))
            : name

        guard !visibleName.isEmpty else { return nil }
        return visibleName
    }
}
