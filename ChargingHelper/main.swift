import Foundation
import AidenteShared
import Darwin
import Security
import os.log
import smc_power

let logger = Logger(
    subsystem: "com.aidente.app.control",
    category: "ServiceDelegate"
)

let localService = CommandLine.arguments.contains("--local-service")
let restoreLocalDefaults = CommandLine.arguments.contains("--restore-local-defaults")
if (localService || restoreLocalDefaults) && getuid() != 0 { exit(77) }

func localClientRequirement() -> String? {
    let path = LocalControlIdentity.manifest
    var metadata = stat()
    guard lstat(path, &metadata) == 0, metadata.st_uid == 0,
          metadata.st_mode & S_IFMT == S_IFREG, metadata.st_mode & 0o022 == 0,
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let fields = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
          let hash = fields["clientCDHash"] else { return nil }
    return LocalControlIdentity.requirement(cdHash: hash)
}

let battery: SMCBattery
let adapter: SMCAdapter
do {
    battery = try SMCBattery.probe()
    adapter = try SMCAdapter.probe()
} catch {
    logger.fault("Failed to probe SMC capabilities: \(error.localizedDescription)")
    exit(1)
}

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    let helper: ChargingHelper

    init(helper: ChargingHelper) {
        self.helper = helper
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        var consoleStatus = stat()
        let consoleUserIdentifier = "/dev/console".withCString {
            Darwin.lstat($0, &consoleStatus) == 0 ? consoleStatus.st_uid : uid_t.max
        }
        let clientUserIdentifier = newConnection.effectiveUserIdentifier
        guard clientUserIdentifier == 0 || clientUserIdentifier == consoleUserIdentifier else {
            logger.error(
                "Rejected XPC connection from uid \(clientUserIdentifier); console uid is \(consoleUserIdentifier)"
            )
            return false
        }
        guard isAuthorizedClient(processIdentifier: newConnection.processIdentifier) else {
            logger.error(
                "Rejected XPC connection from unauthorized pid \(newConnection.processIdentifier)"
            )
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(
            with: (any AidenteControlProtocol).self
        )
        newConnection.exportedObject = helper

        logger.info("XPC connection accepted")
        helper.clientConnected(pid: newConnection.processIdentifier)

        newConnection.invalidationHandler = { [weak self] in
            guard let self else { return }
            self.helper.clientDisconnected()
        }

        newConnection.resume()
        return true
    }

    private func isAuthorizedClient(processIdentifier: pid_t) -> Bool {
        if localService {
            // launchd/XPC enforces the root-owned cdhash pin for every incoming
            // connection, avoiding PID-reuse authentication races. Path and
            // console-user checks are additional restrictions, not fallbacks.
            return executableURL(for: processIdentifier)?.path == LocalControlIdentity.clientPath
        }
        guard
            let clientExecutableURL = executableURL(for: processIdentifier),
            let helperExecutableURL = executableURL(for: getpid())
        else {
            logger.error("Could not resolve executable path for pid \(processIdentifier)")
            return false
        }

        // The daemon and app executable are installed side-by-side in
        // Aidente.app/Contents/MacOS. Matching the kernel-reported executable
        // path prevents another process from connecting while still supporting
        // the ad-hoc signature used by local builds.
        guard let contentsURL = containingAppContentsURL(for: helperExecutableURL) else {
            logger.error("Could not locate the containing Aidente app bundle")
            return false
        }
        let expectedAppExecutableURL = contentsURL
            .appendingPathComponent("MacOS/Aidente")
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard clientExecutableURL == expectedAppExecutableURL else {
            logger.error(
                "Rejected pid \(processIdentifier) at unexpected path \(clientExecutableURL.path, privacy: .public)"
            )
            return false
        }

        var guestCode: SecCode?
        let attributes = [
            kSecGuestAttributePid as String: NSNumber(value: processIdentifier)
        ] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(
            nil,
            attributes,
            SecCSFlags(),
            &guestCode
        ) == errSecSuccess, let guestCode else {
            // Exact executable-path matching is the compatibility fallback for
            // local ad-hoc builds, whose runtime validity check can fail even
            // though the enclosing app passes codesign verification.
            logger.warning("Could not inspect client signature; rejecting connection")
            return false
        }

        var guestStaticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(
            guestCode,
            SecCSFlags(),
            &guestStaticCode
        ) == errSecSuccess, let guestStaticCode else {
            logger.warning("Could not inspect static client signature; rejecting connection")
            return false
        }

        var expectedStaticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            expectedAppExecutableURL as CFURL,
            SecCSFlags(),
            &expectedStaticCode
        ) == errSecSuccess, let expectedStaticCode else {
            logger.warning("Could not inspect installed app signature; rejecting connection")
            return false
        }

        guard
            let guestIdentity = signingIdentity(for: guestStaticCode),
            let expectedIdentity = signingIdentity(for: expectedStaticCode)
        else {
            logger.warning("Missing signing identity; rejecting connection")
            return false
        }

        return guestIdentity.identifier == "com.aidente.app"
            && guestIdentity.identifier == expectedIdentity.identifier
            && guestIdentity.cdHash == expectedIdentity.cdHash
    }

    private func executableURL(for processIdentifier: pid_t) -> URL? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(
            processIdentifier,
            &pathBuffer,
            UInt32(pathBuffer.count)
        )
        guard length > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: pathBuffer))
            .resolvingSymlinksInPath()
            .standardizedFileURL
    }

    private func containingAppContentsURL(for executableURL: URL) -> URL? {
        var candidate = executableURL.deletingLastPathComponent()
        while candidate.path != "/" {
            if candidate.lastPathComponent == "Contents",
                candidate.deletingLastPathComponent().pathExtension == "app"
            {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return nil
    }

    private func signingIdentity(
        for code: SecStaticCode
    ) -> (identifier: String, cdHash: Data)? {
        var signingInformation: CFDictionary?
        guard SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInformation
        ) == errSecSuccess,
            let information = signingInformation as? [String: Any],
            let identifier = information[kSecCodeInfoIdentifier as String] as? String,
            let cdHash = information[kSecCodeInfoUnique as String] as? Data
        else {
            return nil
        }
        return (identifier, cdHash)
    }
}

let helper = ChargingHelper(battery: battery, adapter: adapter)
if restoreLocalDefaults {
    let done = DispatchSemaphore(value: 0)
    helper.restoreDefaults { success, error in
        if !success { logger.error("UNINSTALL_RESTORE_FAILED \(error ?? "unknown", privacy: .public)") }
        exit(success ? 0 : 1)
    }
    _ = done.wait(timeout: .now() + 10)
    exit(1)
}
let delegate = ServiceDelegate(helper: helper)
let listener = NSXPCListener(
    machServiceName: localService ? LocalControlIdentity.label : "com.aidente.app.control"
)
if localService {
    guard let requirement = localClientRequirement() else {
        logger.fault("LOCAL_CLIENT_IDENTITY_MISSING")
        exit(78)
    }
    listener.setConnectionCodeSigningRequirement(requirement)
}
listener.delegate = delegate
listener.resume()

dispatchMain()
