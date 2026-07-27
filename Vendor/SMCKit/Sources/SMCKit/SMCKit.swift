import Foundation
import IOKit
import SMC

public final class SMCKit: Sendable {
    public static let shared: SMCKit = try! SMCKit()

    private let connection: io_connect_t

    private init() throws {
        var conn: io_connect_t = 0
        let result = SMCOpen(&conn)

        guard result == kIOReturnSuccess else {
            throw SMCError.connectionFailed(kIOReturn: result)
        }
        self.connection = conn
    }

    deinit {
        SMCClose(connection)
    }

    public func getKeyInformation(_ key: FourCharCode) throws -> DataType {
        var keyInfo = SMCKeyData_keyInfo_t()
        let result = SMCGetKeyInfo(key, &keyInfo, self.connection)
        try check(result, key: key.toString())
        return DataType(
            type: keyInfo.dataType,
            size: UInt32(keyInfo.dataSize)
        )
    }

    public func isKeyFound(_ key: FourCharCode) throws -> Bool {
        do {
            _ = try getKeyInformation(key)
            return true
        } catch SMCError.keyNotFound {
            return false
        }
    }

    public func read<V: SMCCodable>(_ key: FourCharCode) throws -> V {
        var keyCharArray = key.toCharArray()
        var smcVal = SMCVal_t()

        let result = SMCReadKey(&keyCharArray, &smcVal, self.connection)
        try check(result, key: key.toString())
        return try V(smcVal.bytes)
    }

    public func write<V: SMCCodable>(_ key: FourCharCode, _ value: V) throws {
        var buf = SMCVal_t(
            key: key.toCharArray(),
            dataSize: V.smcDataType.size,
            dataType: V.smcDataType.type.toCharArray(),
            bytes: try value.encode()
        )

        let result = SMCWriteKey(&buf, self.connection)
        try check(result, key: key.toString())
    }

    public func readData(_ key: FourCharCode) throws -> Data {
        var keyCharArray = key.toCharArray()
        var smcVal = SMCVal_t()

        let result = SMCReadKey(&keyCharArray, &smcVal, self.connection)
        try check(result, key: key.toString())

        let validSize = min(Int(smcVal.dataSize), MemoryLayout<SMCBytes_t>.size)
        return withUnsafeBytes(of: smcVal.bytes) { buffer in
            Data(buffer.prefix(validSize))
        }
    }

    public func readString(_ key: FourCharCode) throws -> String {
        var keyCharArray = key.toCharArray()
        var smcVal = SMCVal_t()

        let result = SMCReadKey(&keyCharArray, &smcVal, self.connection)
        try check(result, key: key.toString())

        let validSize = min(Int(smcVal.dataSize), MemoryLayout<SMCBytes_t>.size)
        let bytes = withUnsafeBytes(of: smcVal.bytes) { buffer in
            Array(buffer.prefix(validSize))
        }

        let endIndex = bytes.firstIndex(of: 0) ?? bytes.count
        let stringBytes = Array(bytes.prefix(endIndex))

        guard let string = String(bytes: stringBytes, encoding: .ascii) else {
            throw SMCError.invalidStringData(key: key.toString())
        }
        return string
    }

    public func writeData(_ key: FourCharCode, _ value: Data) throws {
        let keyInfo = try getKeyInformation(key)

        guard keyInfo.type == DataTypes.HexData.type else {
            throw SMCError.dataTypeMismatch(key: key.toString())
        }

        guard value.count == keyInfo.size else {
            throw SMCError.invalidDataSize(
                key: key.toString(),
                expected: keyInfo.size,
                actual: UInt32(value.count)
            )
        }

        var buf = SMCVal_t(
            key: key.toCharArray(),
            dataSize: keyInfo.size,
            dataType: keyInfo.type.toCharArray(),
            bytes: smcBytes(Array(value))
        )

        let result = SMCWriteKey(&buf, self.connection)
        try check(result, key: key.toString())
    }

    public func writeString(_ key: FourCharCode, _ value: String) throws {
        let keyInfo = try getKeyInformation(key)

        guard keyInfo.type == DataTypes.Ch8String.type else {
            throw SMCError.dataTypeMismatch(key: key.toString())
        }

        guard let stringBytes = value.data(using: .ascii) else {
            throw SMCError.invalidStringData(key: key.toString())
        }

        guard stringBytes.count <= keyInfo.size else {
            throw SMCError.invalidDataSize(
                key: key.toString(),
                expected: keyInfo.size,
                actual: UInt32(stringBytes.count)
            )
        }

        var buf = SMCVal_t(
            key: key.toCharArray(),
            dataSize: keyInfo.size,
            dataType: keyInfo.type.toCharArray(),
            bytes: smcBytes(Array(stringBytes))
        )

        let result = SMCWriteKey(&buf, self.connection)
        try check(result, key: key.toString())
    }

    public func numKeys() throws -> UInt32 {
        let result: BigEndian<UInt32> = try self.read(FourCharCode(fromStaticString: "#KEY"))
        return result.value
    }

    public func allKeys() throws -> [FourCharCode] {
        let numKeys = try self.numKeys()
        var keys: [FourCharCode] = []
        keys.reserveCapacity(Int(numKeys))

        for index in 0..<numKeys {
            var keyBuffer = UInt32Char_t(chars: (0, 0, 0, 0, 0))
            let result = SMCGetKeyFromIndex(index, &keyBuffer, self.connection)
            try check(result, key: "Index \(index)")
            keys.append(FourCharCode(fromCharArray: keyBuffer))
        }

        return keys
    }

    private func check(_ result: SMCResult_t, key: String) throws {
        switch (result.kern_res, result.smc_res) {
        case (kIOReturnSuccess, UInt8(kSMCReturnSuccess)):
            return
        case (kIOReturnSuccess, UInt8(kSMCReturnKeyNotFound)):
            throw SMCError.keyNotFound(key: key)
        case (kIOReturnBadArgument, UInt8(kSMCReturnDataTypeMismatch)):
            throw SMCError.dataTypeMismatch(key: key)
        case (kIOReturnNotPrivileged, _):
            throw SMCError.notPrivileged
        default:
            throw SMCError.unknown(
                key: key,
                kIOReturn: result.kern_res,
                SMCResult: result.smc_res
            )
        }
    }
}
