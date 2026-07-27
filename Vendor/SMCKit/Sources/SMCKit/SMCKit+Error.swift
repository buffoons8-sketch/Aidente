import Foundation
import SMC

public enum SMCError: Error {
    case keyNotFound(key: String)
    case notPrivileged
    case dataTypeMismatch(key: String)
    case connectionFailed(kIOReturn: kern_return_t)
    case invalidDataSize(key: String, expected: UInt32, actual: UInt32)
    case invalidStringData(key: String)

    /// https://developer.apple.com/library/mac/qa/qa1075/_index.html
    ///
    /// - parameter key: The SMC key that triggered the error
    /// - parameter kIOReturn: I/O Kit error code
    /// - parameter SMCResult: SMC specific return code
    case unknown(
        key: String,
        kIOReturn: kern_return_t,
        SMCResult: smc_return_t
    )
}
