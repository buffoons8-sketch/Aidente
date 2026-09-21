import Foundation

public enum LocalControlIdentity {
    public static let label = "com.aidente.app.control.local"
    public static let directory = "/Library/PrivilegedHelperTools/com.aidente.app.local"
    public static let executable = directory + "/AidenteControl"
    public static let manifest = directory + "/client.plist"
    public static let launchPlist = "/Library/LaunchDaemons/" + label + ".plist"
    public static let clientPath = "/Applications/Aidente.app/Contents/MacOS/Aidente"

    public static func isHex(_ value: String, length: Int) -> Bool {
        value.utf8.count == length && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    public static func requirement(cdHash: String) -> String? {
        guard isHex(cdHash, length: 40) else { return nil }
        return "identifier \"com.aidente.app\" and cdhash H\"\(cdHash)\""
    }
}
