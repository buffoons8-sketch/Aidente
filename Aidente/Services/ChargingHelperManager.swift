import Foundation
import AidenteShared
import ServiceManagement
import os.log

enum ChargingHelperStatus {
    case notInstalled
    case requiresApproval
    case installed
}

enum ChargingHelperManagerError: LocalizedError {
    case runningFromDiskImage

    var errorDescription: String? {
        switch self {
        case .runningFromDiskImage:
            AidenteL10n.t(
                "Aidente 正在从安装磁盘映像中运行。请先退出应用，将 Aidente 拖入“应用程序”文件夹，再从“应用程序”中打开。",
                "Aidente is running from a disk image. Quit the app, drag it to Applications, then open it from Applications."
            )
        }
    }
}

@MainActor
@Observable
class ChargingHelperManager {
    static let shared = ChargingHelperManager()

    private static let machServiceName = "com.aidente.app.control"
    private static let plistName = "com.aidente.app.control.plist"

    private let service: SMAppService
    private var connection: NSXPCConnection?
    private let logger = Logger(
        subsystem: "com.aidente.app",
        category: "ChargingHelperManager"
    )

    private(set) var helperStatus: ChargingHelperStatus
    private(set) var registrationError: String?

    var isInstalled: Bool {
        service.status == .enabled
    }

    var isRunningFromDiskImage: Bool {
        Bundle.main.bundleURL.resolvingSymlinksInPath().path.hasPrefix("/Volumes/")
    }

    private init() {
        service = SMAppService.daemon(plistName: Self.plistName)
        switch service.status {
        case .enabled: helperStatus = .installed
        case .requiresApproval: helperStatus = .requiresApproval
        default: helperStatus = .notInstalled
        }
    }

    func install() throws {
        guard !isRunningFromDiskImage else {
            throw ChargingHelperManagerError.runningFromDiskImage
        }
        logger.info("Registering charging helper daemon")

        do {
            try service.register()
        } catch {
            // register() commonly throws "Operation not permitted" while macOS
            // processes the background item notification, even though the
            // registration advanced to requiresApproval or enabled.
            if service.status != .enabled && service.status != .requiresApproval {
                registrationError = error.localizedDescription
                throw error
            }
        }

        registrationError = nil
        refreshStatus()
    }

    func ensureInstalled() throws {
        refreshStatus()
        guard helperStatus == .notInstalled else { return }
        try install()
    }

    func repair() async throws {
        guard !isRunningFromDiskImage else {
            throw ChargingHelperManagerError.runningFromDiskImage
        }

        logger.info("Repairing charging helper daemon registration")
        disconnect()
        if service.status == .enabled || service.status == .requiresApproval {
            try await unregisterAndWait()
        }
        try install()
    }

    func uninstall() throws {
        logger.info("Unregistering charging helper daemon")
        disconnect()
        try service.unregister()
        helperStatus = .notInstalled
    }

    func refreshStatus() {
        switch service.status {
        case .enabled: helperStatus = .installed
        case .requiresApproval: helperStatus = .requiresApproval
        default: helperStatus = .notInstalled
        }
    }

    func getHelper(errorHandler: @escaping @Sendable (Error) -> Void) -> AidenteControlProtocol? {
        if connection == nil {
            connect()
        }
        guard let connection else { return nil }
        return connection.remoteObjectProxyWithErrorHandler(errorHandler)
            as? AidenteControlProtocol
    }

    private func connect() {
        logger.info("Setting up XPC connection to charging helper daemon")
        let newConnection = NSXPCConnection(
            machServiceName: Self.machServiceName
        )
        newConnection.remoteObjectInterface = NSXPCInterface(
            with: AidenteControlProtocol.self
        )

        newConnection.invalidationHandler = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.logger.warning("Charging helper XPC connection invalidated")
                self.connection = nil
            }
        }

        newConnection.interruptionHandler = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.logger.warning("Charging helper XPC connection interrupted")
                self.connection = nil
            }
        }

        newConnection.resume()
        connection = newConnection
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
    }

    private func unregisterAndWait() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            service.unregister { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        helperStatus = .notInstalled
    }
}
