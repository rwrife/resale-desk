import ResaleDeskKit

/// ResaleDeskStore persistence layer namespace.
///
/// M2 implements GRDB migrations, append-only triggers, and local repositories;
/// M6 adds versioned JSON backup and CSV exports.
public enum ResaleDeskStore {
    /// Namespace identifier.
    public static let domain = "ResaleDeskStore"

    /// Current persistence schema milestone marker.
    public static let milestone = "M2-store"
}
