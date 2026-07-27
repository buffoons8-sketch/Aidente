import Foundation
import SMC

extension FourCharCode: @retroactive ExpressibleByStringLiteral {
    public init(fromStaticString str: StaticString) {
        precondition(str.utf8CodeUnitCount == 4)

        self = str.withUTF8Buffer { buffer in
            buffer.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        }
    }

    public init(stringLiteral value: String) {
        precondition(
            value.count == 4,
            "FourCharCode must be exactly 4 characters"
        )
        let bytes = Array(value.utf8)
        precondition(
            bytes.count == 4,
            "FourCharCode must be exactly 4 UTF-8 bytes"
        )
        self =
            (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16)
            | (UInt32(bytes[2]) << 8)
            | UInt32(bytes[3])
    }

    public init(fromCharArray charArray: UInt32Char_t) {
        self =
            (UInt32(charArray.chars.0) << 24)
            | (UInt32(charArray.chars.1) << 16)
            | (UInt32(charArray.chars.2) << 8)
            | UInt32(charArray.chars.3)
    }

    public func toString() -> String {
        let bytes: [UInt8] = [
            UInt8((self >> 24) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8(self & 0xFF),
        ]
        return String(bytes.map { Character(UnicodeScalar($0)) })
    }

    internal func toCharArray() -> UInt32Char_t {
        return UInt32Char_t(
            chars: (
                UInt8((self >> 24) & 0xFF),
                UInt8((self >> 16) & 0xFF),
                UInt8((self >> 8) & 0xFF),
                UInt8(self & 0xFF),
                UInt8(0)
            )
        )
    }
}

public struct DataType: Equatable {
    public let type: FourCharCode
    public let size: UInt32
}

// TODO Other DataTypes from other machines?
enum DataTypes {
    static let UInt8 = DataType(
        type: FourCharCode(fromStaticString: "ui8 "),
        size: 1
    )
    static let UInt16 = DataType(
        type: FourCharCode(fromStaticString: "ui16"),
        size: 2
    )
    static let UInt32 = DataType(
        type: FourCharCode(fromStaticString: "ui32"),
        size: 4
    )
    static let UInt64 = DataType(
        type: FourCharCode(fromStaticString: "ui64"),
        size: 8
    )

    static let Int8 = DataType(
        type: FourCharCode(fromStaticString: "si8 "),
        size: 1
    )
    static let Int16 = DataType(
        type: FourCharCode(fromStaticString: "si16"),
        size: 2
    )
    static let Int32 = DataType(
        type: FourCharCode(fromStaticString: "si32"),
        size: 4
    )
    static let Int64 = DataType(
        type: FourCharCode(fromStaticString: "si64"),
        size: 8
    )

    static let Flag = DataType(
        type: FourCharCode(fromStaticString: "flag"),
        size: 1
    )
    static let Float = DataType(
        type: FourCharCode(fromStaticString: "flt "),
        size: 4
    )

    static let HexData = DataType(
        type: FourCharCode(fromStaticString: "hex_"),
        size: 0
    )
    static let Ch8String = DataType(
        type: FourCharCode(fromStaticString: "ch8*"),
        size: 0
    )
}

public protocol SMCCodable {
    static var smcDataType: DataType { get }
    init(_ raw: SMCBytes_t) throws
    func encode() throws -> SMCBytes_t
}

@inlinable func smcBytes(_ slice: [UInt8]) -> SMCBytes_t {
    var tmp = [UInt8](repeating: 0, count: 32)
    tmp.replaceSubrange(0..<min(slice.count, 32), with: slice)
    return tmp.withUnsafeBytes {
        $0.load(as: SMCBytes_t.self)
    }
}

@inlinable func toBytes<T>(_ v: T) -> [UInt8] {
    withUnsafeBytes(of: v) { Array($0) }
}
@inlinable func fromBytes<T>(_ b: [UInt8]) -> T {
    b.withUnsafeBytes { $0.load(as: T.self) }
}

extension UInt8: SMCCodable {
    public static var smcDataType: DataType { DataTypes.UInt8 }

    public init(_ raw: SMCBytes_t) throws {
        self = raw.0
    }

    public func encode() throws -> SMCBytes_t {
        smcBytes([self])
    }
}

extension UInt16: SMCCodable {
    public static var smcDataType: DataType { DataTypes.UInt16 }

    public init(_ raw: SMCBytes_t) throws {
        self = UInt16(raw.0) | (UInt16(raw.1) << 8)
    }

    public func encode() throws -> SMCBytes_t {
        smcBytes([UInt8(self & 0xFF), UInt8(self >> 8)])
    }
}

extension UInt32: SMCCodable {
    public static var smcDataType: DataType { DataTypes.UInt32 }

    public init(_ raw: SMCBytes_t) throws {
        self =
            UInt32(raw.0) | (UInt32(raw.1) << 8)
            | (UInt32(raw.2) << 16) | (UInt32(raw.3) << 24)
    }

    public func encode() throws -> SMCBytes_t {
        smcBytes([
            UInt8(self & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 24) & 0xFF),
        ])
    }
}

extension Int8: SMCCodable {
    public static var smcDataType: DataType { DataTypes.Int8 }

    public init(_ raw: SMCBytes_t) throws {
        self = Int8(bitPattern: raw.0)
    }

    public func encode() throws -> SMCBytes_t {
        smcBytes([UInt8(bitPattern: self)])
    }
}

extension Int16: SMCCodable {
    public static var smcDataType: DataType { DataTypes.Int16 }

    public init(_ raw: SMCBytes_t) throws {
        let unsigned = UInt16(raw.0) | (UInt16(raw.1) << 8)
        self = Int16(bitPattern: unsigned)
    }

    public func encode() throws -> SMCBytes_t {
        let u = UInt16(bitPattern: self)
        return smcBytes([UInt8(u & 0xFF), UInt8(u >> 8)])
    }
}

extension Int32: SMCCodable {
    public static var smcDataType: DataType { DataTypes.Int32 }

    public init(_ raw: SMCBytes_t) throws {
        let u =
            UInt32(raw.0) | (UInt32(raw.1) << 8) | (UInt32(raw.2) << 16)
            | (UInt32(raw.3) << 24)
        self = Int32(bitPattern: u)
    }

    public func encode() throws -> SMCBytes_t {
        let u = UInt32(bitPattern: self)
        return smcBytes([
            UInt8(u & 0xFF),
            UInt8((u >> 8) & 0xFF),
            UInt8((u >> 16) & 0xFF),
            UInt8((u >> 24) & 0xFF),
        ])
    }
}

extension UInt64: SMCCodable {
    public static var smcDataType: DataType { DataTypes.UInt64 }

    public init(_ raw: SMCBytes_t) throws {
        self =
            UInt64(raw.0) | (UInt64(raw.1) << 8)
            | (UInt64(raw.2) << 16) | (UInt64(raw.3) << 24)
            | (UInt64(raw.4) << 32) | (UInt64(raw.5) << 40)
            | (UInt64(raw.6) << 48) | (UInt64(raw.7) << 56)
    }

    public func encode() throws -> SMCBytes_t {
        smcBytes([
            UInt8(self & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 24) & 0xFF),
            UInt8((self >> 32) & 0xFF),
            UInt8((self >> 40) & 0xFF),
            UInt8((self >> 48) & 0xFF),
            UInt8((self >> 56) & 0xFF),
        ])
    }
}

extension Int64: SMCCodable {
    public static var smcDataType: DataType { DataTypes.Int64 }

    public init(_ raw: SMCBytes_t) throws {
        let u =
            UInt64(raw.0) | (UInt64(raw.1) << 8)
            | (UInt64(raw.2) << 16) | (UInt64(raw.3) << 24)
            | (UInt64(raw.4) << 32) | (UInt64(raw.5) << 40)
            | (UInt64(raw.6) << 48) | (UInt64(raw.7) << 56)
        self = Int64(bitPattern: u)
    }

    public func encode() throws -> SMCBytes_t {
        let u = UInt64(bitPattern: self)
        return smcBytes([
            UInt8(u & 0xFF),
            UInt8((u >> 8) & 0xFF),
            UInt8((u >> 16) & 0xFF),
            UInt8((u >> 24) & 0xFF),
            UInt8((u >> 32) & 0xFF),
            UInt8((u >> 40) & 0xFF),
            UInt8((u >> 48) & 0xFF),
            UInt8((u >> 56) & 0xFF),
        ])
    }
}

extension Float: SMCCodable {
    public static var smcDataType: DataType { DataTypes.Float }

    public init(_ raw: SMCBytes_t) throws {
        let bytes = [raw.0, raw.1, raw.2, raw.3]
        self = fromBytes(bytes)
    }

    public func encode() throws -> SMCBytes_t {
        smcBytes(toBytes(self))
    }
}

extension Bool: SMCCodable {
    public static var smcDataType: DataType { DataTypes.Flag }

    public init(_ raw: SMCBytes_t) throws {
        self = (raw.0 != 0)
    }

    public func encode() throws -> SMCBytes_t {
        smcBytes([self ? 1 : 0])
    }
}

// MARK: - Big-Endian Wrapper

/// A wrapper for reading/writing SMC keys that store integer values in big-endian byte order.
///
/// Most SMC keys on Apple Silicon use little-endian byte order, which is what the default
/// `SMCCodable` conformances use. However, a small number of keys (e.g. `#KEY`, `RBID`, `RBRV`,
/// `D1BD`, `FOFC`, `MPPR`) store values in big-endian order. Use this wrapper for those keys.
///
/// ```swift
/// let count: BigEndian<UInt32> = try await SMCKit.shared.read("#KEY")
/// print(count.value) // 3209
/// ```
public struct BigEndian<Value: FixedWidthInteger & SMCCodable>: SMCCodable {
    public let value: Value

    public init(_ value: Value) {
        self.value = value
    }

    public static var smcDataType: DataType { Value.smcDataType }

    public init(_ raw: SMCBytes_t) throws {
        // Read bytes in big-endian order (most significant byte first)
        var result: Value = 0
        withUnsafeBytes(of: raw) { buffer in
            let size = MemoryLayout<Value>.size
            for i in 0..<size {
                result |= Value(buffer[i]) << ((size - 1 - i) * 8)
            }
        }
        self.value = result
    }

    public func encode() throws -> SMCBytes_t {
        // Write bytes in big-endian order (most significant byte first)
        let size = MemoryLayout<Value>.size
        var bytes = [UInt8](repeating: 0, count: size)
        for i in 0..<size {
            bytes[i] = UInt8((value >> ((size - 1 - i) * 8)) & 0xFF)
        }
        return smcBytes(bytes)
    }
}
