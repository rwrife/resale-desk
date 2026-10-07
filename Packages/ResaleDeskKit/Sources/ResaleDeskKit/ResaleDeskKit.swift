/// ResaleDeskKit — pure-domain models and rubric engine for Resale Desk.
///
/// Issue #1 (M1) ships only the skeleton namespace so CI has a real,
/// testable target. Issue #2 (M2) lands the Item, RubricTemplate,
/// ConditionAnswer, Grade, and append-only event models here.
public enum ResaleDeskKit {
    /// Namespace marker for the domain layer.
    public static let domain = "ResaleDeskKit"

    /// Current build/CI milestone marker consumed by the app's debug surface.
    public static let milestone = "M1-skeleton"
}
