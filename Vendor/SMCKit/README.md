# SMCKit

Swift wrapper for the Apple System Management Controller (SMC) with type-safe reading/writing and a standalone C library.

Updated implementation of the original [SMCKit Project](https://github.com/beltex/SMCKit). Provides generic types for reading and writing SMC values, hash map-based caching, and a standalone C library for cross-language compatibility.

## Requirements

- Swift 5.9+
- Xcode 15.0+

## Quick Start

### Swift

```swift
import SMCKit

let temp: Float = try SMCKit.shared.read("TC0P")
print("CPU Temperature: \(temp)°C")
```

### C Library

```c
#include <smc.h>

io_connect_t conn;
if (SMCOpen(&conn) != kIOReturnSuccess) {
    // Handle error
}

UInt32Char_t key = {{'T', 'C', '0', 'P', '\0'}};
SMCVal_t val;

SMCResult_t result = SMCReadKey(&key, &val, conn);
if (result.kern_res == kIOReturnSuccess && result.smc_res == kSMCReturnSuccess) {
    // Use val.bytes
}

SMCClose(conn);
```

## Usage

### Reading Values

```swift
let temp: Float = try SMCKit.shared.read("TC0P")
let fanSpeed: UInt16 = try SMCKit.shared.read("F0Ac")
let flag: Bool = try SMCKit.shared.read("SOME")
```

### Writing Values

```swift
try SMCKit.shared.write("SOME", UInt32(42))
```

### Byte Ordering

All integer types use **little-endian** byte order, matching the vast majority of SMC keys on Apple Silicon Macs.

A small number of keys (e.g. `#KEY`, `RBID`, `RBRV`, `D1BD`, `FOFC`, `MPPR`) use big-endian byte order. Use the `BigEndian` wrapper for these:

```swift
let count: BigEndian<UInt32> = try SMCKit.shared.read("#KEY")
print(count.value)

try SMCKit.shared.write("RBID", BigEndian<UInt32>(4))
```

### Variable-Length Types (hex_, ch8*)

```swift
// Raw binary data (hex_ type)
let data: Data = try SMCKit.shared.readData("SOME")
try SMCKit.shared.writeData("SOME", Data([0x01, 0x02, 0x03, 0x04]))

// ASCII string (ch8* type) — null padding is automatically handled
let name: String = try SMCKit.shared.readString("RPlt")
try SMCKit.shared.writeString("RPlt", "j614s")
```

### Querying Keys

```swift
let exists = try SMCKit.shared.isKeyFound("TC0P")

let info = try SMCKit.shared.getKeyInformation("TC0P")
print("Type: \(info.type), Size: \(info.size)")

let count = try SMCKit.shared.numKeys()

let allKeys = try SMCKit.shared.allKeys()
```

## Supported Types

Fixed-size types via `SMCCodable` (integer types use little-endian byte order):

- `UInt8`, `UInt16`, `UInt32`, `UInt64`
- `Int8`, `Int16`, `Int32`, `Int64`
- `Float`
- `Bool`
- `BigEndian<T>` — for keys that use big-endian byte order

Variable-length types via dedicated methods:

- `Data` — raw binary (`hex_` type) via `readData`/`writeData`
- `String` — ASCII strings (`ch8*` type) via `readString`/`writeString`

## Error Handling

```swift
do {
    let temp: Float = try SMCKit.shared.read("TC0P")
} catch SMCError.keyNotFound(let key) {
    print("Key not found: \(key)")
} catch SMCError.notPrivileged {
    print("Need elevated privileges")
} catch SMCError.dataTypeMismatch(let key) {
    print("Wrong data type for key: \(key)")
} catch SMCError.connectionFailed(let kIOReturn) {
    print("Failed to connect to SMC: \(kIOReturn)")
} catch SMCError.invalidDataSize(let key, let expected, let actual) {
    print("Size mismatch for \(key): expected \(expected), got \(actual)")
} catch SMCError.invalidStringData(let key) {
    print("Invalid ASCII string data for key: \(key)")
}
```

## Architecture

### Swift Layer (SMCKit)
- `final class` conforming to `Sendable` — safe to share across concurrency contexts
- Generic `SMCCodable` protocol for compile-time type safety
- String literal keys (`"TC0P"` instead of `FourCharCode(fromStaticString: "TC0P")`)

### C Library (libsmc)
- Standalone — usable independently in C/C++ projects
- Global hash map cache with pthread mutex protection to minimize SMC calls

## License

MIT License - See LICENSE file for details

## Credits

Based on the original [SMCKit](https://github.com/beltex/SMCKit) by beltex.
