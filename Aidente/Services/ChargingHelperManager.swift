import Foundation
import AidenteShared
import ServiceManagement
import os.log

enum ChargingHelperStatus { case notInstalled, requiresApproval, installed }
enum ChargingHelperManagerError: LocalizedError {
    case runningFromDiskImage
    var errorDescription: String? {
        AidenteL10n.t("请先退出磁盘映像中的 Aidente，将软件安装到“应用程序”后重新打开。",
                     "Install Aidente in Applications and reopen it before enabling charging control.")
    }
}

@MainActor @Observable
final class ChargingHelperManager {
    static let shared = ChargingHelperManager()
    private var connection: NSXPCConnection?
    private var operation: Task<Void, Error>?
    private var failure: Error?
    private var verified = false
    private let logger = Logger(subsystem: "com.aidente.app", category: "ChargingHelperManager")
    private(set) var helperStatus: ChargingHelperStatus = .notInstalled
    private(set) var registrationError: String?
    private(set) var isBusy = false
    var isInstalled: Bool { helperStatus == .installed }
    var isRunningFromDiskImage: Bool { Bundle.main.bundlePath.hasPrefix("/Volumes/") }
    private init() { refreshStatus() }

    func refreshStatus() {
        helperStatus = LocalControlInstaller.installedMatchesCurrentApp() ? .installed : .notInstalled
    }
    // Startup and polling NEVER request administrator privileges.
    func ensureInstalled() throws {
        if let failure { throw failure }
        refreshStatus()
        guard isInstalled else {
            throw XPCError.commandFailed(AidenteL10n.t(
                "后台服务未安装或软件已更新。请在充电管理中点击“修复控制服务”并授权安装；无需开发者账号。",
                "The control service is missing or needs updating. Click Repair Control Service and authorize installation; no developer account is required."
            ))
        }
    }
    func prepareForControl() async throws {
        if let operation { return try await operation.value }
        if let failure { throw failure }
        if verified { return }
        let task = Task { @MainActor in
            try ensureInstalled()
            try await ping()
            verified = true
        }
        operation = task
        defer { operation = nil }
        do { try await task.value }
        catch { record(error); throw error }
    }
    func enableForUser() async throws { try await installForUser(force: false) }
    func repair() async throws { try await installForUser(force: true) }
    private func installForUser(force: Bool) async throws {
        if let operation { return try await operation.value }
        let task = Task { @MainActor in
            failure = nil
            guard !isRunningFromDiskImage else { throw ChargingHelperManagerError.runningFromDiskImage }
            refreshStatus()
            if force || !isInstalled {
                disconnect()
                try await LocalControlInstaller.run(uninstall: false)
                // Only after successful authorized installation retire the old
                // embedded registration. Cancelled authorization changes nothing.
                let old = SMAppService.daemon(plistName: "com.aidente.app.control.plist")
                if old.status == .enabled || old.status == .requiresApproval {
                    do { try await old.unregister() }
                    catch { logger.warning("Legacy unregister failed: \(error.localizedDescription, privacy: .public)") }
                }
            }
            refreshStatus()
            guard isInstalled else { throw XPCError.helperUnavailable }
            try await ping()
            verified = true
            registrationError = nil
        }
        operation = task
        isBusy = true
        defer { operation = nil; isBusy = false }
        do { try await task.value }
        catch { record(error); throw error }
    }
    func uninstall() async throws {
        if let operation { try await operation.value }
        let task = Task { @MainActor in
            disconnect()
            // Root installer restores power before removing the recovery tool,
            // even if an app update invalidated the old client pin.
            try await LocalControlInstaller.run(uninstall: true)
            failure = nil
            registrationError = nil
            refreshStatus()
        }
        operation = task
        isBusy = true
        defer { operation = nil; isBusy = false }
        do { try await task.value }
        catch { record(error); throw error }
    }
    private func record(_ error: Error) {
        failure = error
        verified = false
        registrationError = error.localizedDescription
        logger.error("LOCAL_CONTROL_FAILED \(error.localizedDescription, privacy: .public)")
    }
    private func ping() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let reply = XPCCommandReply(continuation)
            guard let helper = getHelper(errorHandler: { reply.finish(.failure($0)) }) else {
                reply.finish(.failure(XPCError.helperUnavailable)); return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) { reply.finish(.failure(XPCError.timeout)) }
            helper.ping { success, message in
                if success { reply.finish(.success(())) }
                else { reply.finish(.failure(XPCError.commandFailed(message ?? "Health check failed"))) }
            }
        }
        logger.notice("LOCAL_CONTROL_HEALTH_OK")
    }
    func getHelper(errorHandler: @escaping @Sendable (Error) -> Void) -> AidenteControlProtocol? {
        if let failure { errorHandler(failure); return nil }
        if connection == nil {
            let newConnection = NSXPCConnection(machServiceName: LocalControlIdentity.label, options: .privileged)
            do {
                let hash = try LocalControlInstaller.signingCDHash(at: Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/AidenteControl"))
                guard LocalControlIdentity.isHex(hash, length: 40) else { throw XPCError.helperUnavailable }
                newConnection.setCodeSigningRequirement("identifier \"com.aidente.app.control\" and cdhash H\"\(hash)\"")
            } catch { errorHandler(error); return nil }
            newConnection.remoteObjectInterface = NSXPCInterface(with: AidenteControlProtocol.self)
            newConnection.invalidationHandler = { [weak self, weak newConnection] in
                Task { @MainActor in
                    guard let self, self.connection === newConnection else { return }
                    self.connection = nil
                    self.verified = false
                }
            }
            newConnection.interruptionHandler = newConnection.invalidationHandler
            newConnection.resume()
            connection = newConnection
        }
        return connection?.remoteObjectProxyWithErrorHandler(errorHandler) as? AidenteControlProtocol
    }
    func disconnect() {
        connection?.invalidate()
        connection = nil
        verified = false
    }
    func recoverAfterTransportFailure(_ error: Error) { disconnect() }
    // Retained diagnostic CLI: verifies integrity, not a paid certificate.
    func validateSigningIdentity() throws { _ = try LocalControlInstaller.clientCDHash() }
}
