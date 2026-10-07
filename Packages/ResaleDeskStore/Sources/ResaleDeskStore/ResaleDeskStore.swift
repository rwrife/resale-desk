import ResaleDeskKit

/// ResaleDeskStore persistence layer namespace.
///
/// M1 provides the package skeleton and wiring stub.
/// M2 implements GRDB migrations and local photo manifests; M6 adds
/// versioned JSON backup and CSV exports.
public enum ResaleDeskStore {
    /// Namespace identifier.
    public static let domain = "ResaleDeskStore"

    /// Current persistence schema milestone marker.
    public static let milestone = "M1-skeleton"
}
