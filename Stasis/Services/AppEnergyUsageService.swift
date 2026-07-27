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
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
            let text = String(data: data, encoding: .utf8)
        else {
            return []
        }

        var totals: [String: (name: String, cpuUsage: Double)] = [:]

        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(
                maxSplits: 2,
                whereSeparator: \.isWhitespace
            )
            guard fields.count == 3,
                let cpuUsage = Double(fields[1]),
                cpuUsage > 0,
                let app = appIdentity(from: String(fields[2])),
                app.name.caseInsensitiveCompare("iadente") != .orderedSame
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

    private static func appIdentity(from command: String) -> (
        bundlePath: String,
        name: String
    )? {
        guard command.hasPrefix("/Applications/")
                || command.hasPrefix("/System/Applications/"),
            let appSuffix = command.range(of: ".app/")
        else {
            return nil
        }

        let appEnd = command.index(appSuffix.lowerBound, offsetBy: 4)
        let bundlePath = String(command[..<appEnd])
        let name = URL(fileURLWithPath: bundlePath)
            .deletingPathExtension()
            .lastPathComponent

        guard !name.isEmpty else { return nil }
        return (bundlePath, name)
    }
}
