import Foundation
import AidenteShared
import Security

enum AidenteL10n { static func t(_ chinese: String, _ english: String) -> String { chinese } }
enum XPCError: Error { case commandFailed(String) }

@main struct LocalInstallerTests {
    static func main() throws {
        let hash = String(repeating: "a", count: 40)
        precondition(LocalControlIdentity.requirement(cdHash: "\" or true") == nil)
        precondition(LocalControlIdentity.requirement(cdHash: String(repeating: "a", count: 39)) == nil)
        precondition(LocalControlIdentity.requirement(cdHash: String(repeating: "g", count: 40)) == nil)
        let requirement = LocalControlIdentity.requirement(cdHash: hash)!
        var compiled: SecRequirement?
        precondition(SecRequirementCreateWithString(requirement as CFString, [], &compiled) == errSecSuccess)
        let script = try String(contentsOfFile: "BuildSupport/install_local_control.sh", encoding: .utf8)
        let source = LocalControlInstaller.authorizationSource(script: script, arguments: ["install", String(repeating: "b", count: 64), String(repeating: "c", count: 64), hash])
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: source)!
        precondition(appleScript.compileAndReturnError(&error), "Authorization script failed to compile: \(String(describing: error))")
        // Compile only, NEVER execute: no password dialog and no system writes.
        precondition(source.contains("with administrator privileges"))
        precondition(!LocalControlInstaller.installedMatchesCurrentApp())
        // Reproduce the installer's bare-executable copy, not just the bundle.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = URL(fileURLWithPath: "/Applications/Aidente.app")
        let copy = directory.appendingPathComponent("client-snapshot")
        try FileManager.default.copyItem(at: app.appendingPathComponent("Contents/MacOS/Aidente"), to: copy)
        let command = script.components(separatedBy: "\n").first { $0.hasPrefix("actual_cdhash=$(") }!
        // Use the actual production extraction statement, not duplicated flags.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "stage=\"$1\"\n" + command + "\nprintf '%s' \"$actual_cdhash\"", "test", directory.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let actualHash = String(data: output, encoding: .utf8)!
        precondition(process.terminationStatus == 0 && !actualHash.isEmpty, "Installer must extract non-empty CDHash")
        let expectedHash = try LocalControlInstaller.signingCDHash(at: app)
        precondition(actualHash == expectedHash, "Installer CDHash must match Security.framework")
        print("PASS: 9 local-installer checks including real copied-binary CDHash extraction (no system writes)")
    }
}
