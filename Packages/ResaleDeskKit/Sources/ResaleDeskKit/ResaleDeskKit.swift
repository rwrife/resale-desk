/// ResaleDeskKit — pure-domain models and rubric engine for Resale Desk.
///
/// M2 defines Item, condition rubrics and append-only event models.
public enum ResaleDeskKit {
    /// Namespace marker for the domain layer.
    public static let domain = "ResaleDeskKit"

    /// Current build/CI milestone marker consumed by the app's debug surface.
    public static let milestone = "M3-inventory"

    /// Built-in category-appropriate starter rubric templates.
    public static let defaultRubrics: [RubricTemplate] = [
        RubricTemplate(
            id: "apparel-general",
            questions: [
                RubricQuestion(id: "stains", title: "No visible stains or discoloration", required: true),
                RubricQuestion(id: "holes-tears", title: "No holes, tears, or worn fabric", required: true),
                RubricQuestion(id: "hardware", title: "Zippers, buttons, and snaps intact", required: true),
                RubricQuestion(id: "odor", title: "Clean and odor-free", required: true),
                RubricQuestion(id: "original-tags", title: "Original tags / brand labels present", required: false),
            ]
        ),
        RubricTemplate(
            id: "electronics",
            questions: [
                RubricQuestion(id: "powers-on", title: "Powers on and holds charge", required: true),
                RubricQuestion(id: "screen-body", title: "Screen and casing crack-free", required: true),
                RubricQuestion(id: "ports-buttons", title: "All ports and buttons responsive", required: true),
                RubricQuestion(id: "accessories", title: "Original power cable / accessories included", required: false),
            ]
        ),
        RubricTemplate(
            id: "books-media",
            questions: [
                RubricQuestion(id: "binding-spine", title: "Intact binding and tight spine", required: true),
                RubricQuestion(id: "pages-clean", title: "No missing or heavily marked pages", required: true),
                RubricQuestion(id: "cover-jacket", title: "Cover and dust jacket clean", required: true),
                RubricQuestion(id: "first-edition", title: "First edition / print verified", required: false),
            ]
        ),
        RubricTemplate(
            id: "homeware-general",
            questions: [
                RubricQuestion(id: "structural-integrity", title: "No cracks, chips, or warping", required: true),
                RubricQuestion(id: "surface-finish", title: "Surface finish / paint undamaged", required: true),
                RubricQuestion(id: "cleanliness", title: "Thoroughly cleaned and ready to use", required: true),
                RubricQuestion(id: "original-box", title: "Original packaging preserved", required: false),
            ]
        ),
    ]
}
