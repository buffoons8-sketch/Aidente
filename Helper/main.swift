import Foundation
import AidenteShared

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    let helper = Helper()

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(
            with: (any AidenteReaderProtocol).self
        )
        newConnection.exportedObject = helper
        newConnection.resume()
        return true
    }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
