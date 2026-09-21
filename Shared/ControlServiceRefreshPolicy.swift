import Foundation

/// A first launch must verify the newly registered service, not immediately
/// unregister it. Only a previously verified, different build needs migration.
public enum ControlServiceRefreshPolicy {
    public static func needsRefresh(previous: String?, current: String) -> Bool {
        guard let previous else { return false }
        return previous != current
    }
}
