import Foundation
import AidenteShared
import CryptoKit
import Security

enum LocalControlInstaller {
    static func sha256(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }
    static func installedMatchesCurrentApp() -> Bool {
        let url = URL(fileURLWithPath: LocalControlIdentity.manifest)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.ownerAccountID] as? Int == 0,
              attributes[.type] as? FileAttributeType == .typeRegular,
              let mode = attributes[.posixPermissions] as? Int, mode & 0o022 == 0,
              let data = try? Data(contentsOf: url),
              let manifest = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
              let helper = try? sha256(Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/AidenteControl")),
              let executable = Bundle.main.executableURL,
              let client = try? sha256(executable),
              manifest["helperSHA256"] == helper, manifest["clientSHA256"] == client,
              FileManager.default.fileExists(atPath: LocalControlIdentity.executable),
              FileManager.default.fileExists(atPath: LocalControlIdentity.launchPlist) else { return false }
        return true
    }
    static func clientCDHash() throws -> String {
        try signingCDHash(at: Bundle.main.bundleURL)
    }
    static func signingCDHash(at url: URL) throws -> String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code, SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess else {
            throw XPCError.commandFailed("App signature integrity check failed")
        }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let fields = information as? [String: Any],
              let hash = fields[kSecCodeInfoUnique as String] as? Data else {
            throw XPCError.commandFailed("App signing identity unavailable")
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    static func run(uninstall: Bool) async throws {
        guard Bundle.main.bundleURL.standardizedFileURL.path == "/Applications/Aidente.app" else {
            throw XPCError.commandFailed(AidenteL10n.t(
                "请先将 Aidente 安装到“应用程序”文件夹，并从那里启动，再安装后台服务。",
                "Install Aidente in /Applications and open it there before installing its control service."
            ))
        }
        guard let scriptURL = Bundle.main.url(forResource: "install_local_control", withExtension: "sh"),
              let executable = Bundle.main.executableURL else { throw XPCError.commandFailed("Installer resource missing") }
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        var args = [uninstall ? "uninstall" : "install"]
        if !uninstall {
            args += [try sha256(Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/AidenteControl")),
                     try sha256(executable), try clientCDHash()]
        }
        let source = authorizationSource(script: script, arguments: args)
        try await executeAuthorization(source)
    }
    static func authorizationSource(script: String, arguments args: [String]) -> String {
        func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let command = "/bin/sh -c " + quote(script) + " -- " + args.map(quote).joined(separator: " ")
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(escaped)\" with administrator privileges with prompt \"Aidente：安装、更新或移除电池控制后台服务\""
    }
    private static func executeAuthorization(_ source: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let message = String(data: output, encoding: .utf8) ?? "Administrator installation failed"
                throw XPCError.commandFailed(String(message.suffix(1800)))
            }
        }.value
    }
}
