import Foundation
import AidenteShared
import os.log

@MainActor
class SMCReaderConnection {
    private var connection: NSXPCConnection?
    private let serviceName: String
    private let logger = Logger(
        subsystem: "com.aidente.app",
        category: "SMCReaderConnection"
    )

    private var reconnectAttempts = 0
    private var reconnectTask: Task<Void, Never>?
    private static let maxReconnectAttempts = 5
    private static let baseReconnectDelay: TimeInterval = 1.0

    init(serviceName: String) {
        self.serviceName = serviceName
    }

    func getHelper(errorHandler: @escaping @Sendable (Error) -> Void) -> AidenteReaderProtocol? {
        if connection == nil { connect() }
        guard let connection else { return nil }
        return connection.remoteObjectProxyWithErrorHandler(errorHandler)
            as? AidenteReaderProtocol
    }

    func connect() {
        logger.info("Setting up XPC connection to \(self.serviceName)")
        let newConnection = NSXPCConnection(serviceName: serviceName)
        connection = newConnection
        newConnection.remoteObjectInterface = NSXPCInterface(
            with: AidenteReaderProtocol.self
        )

        newConnection.invalidationHandler = { [weak self, weak newConnection] in
            Task { @MainActor in
                guard let self else { return }
                self.logger.error("XPC connection invalidated")
                if self.connection === newConnection { self.connection = nil }
            }
        }

        newConnection.interruptionHandler = { [weak self, weak newConnection] in
            Task { @MainActor in
                guard let self else { return }
                self.logger.warning("XPC connection interrupted")
                if self.connection === newConnection {
                    self.connection = nil
                    newConnection?.invalidate()
                    self.scheduleReconnect()
                }
            }
        }

        newConnection.resume()
        reconnectAttempts = 0
        logger.info("XPC connection resumed")
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < Self.maxReconnectAttempts else {
            logger.error(
                "Exceeded max reconnect attempts (\(Self.maxReconnectAttempts)), giving up"
            )
            return
        }

        reconnectAttempts += 1
        let delay =
            Self.baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        logger.info(
            "Scheduling reconnect attempt \(self.reconnectAttempts) in \(delay)s"
        )

        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self.connect()
        }
    }

    func disconnect() {
        logger.info("Disconnecting XPC connection")
        reconnectTask?.cancel()
        reconnectTask = nil
        connection?.invalidate()
        connection = nil
    }

}
