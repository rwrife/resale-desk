import Foundation

public enum ListingCopy {
    /// Blank means unknown. Accept decimal point or comma, never grouping or rounding.
    public static func cents(_ text: String) throws -> Int64? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        if text.isEmpty { return nil }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, !parts[0].isEmpty,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              parts.count == 1 || (1...2).contains(parts[1].count),
              let whole = Int64(parts[0]) else { throw DomainError.invalidPrice }
        let fraction = parts.count == 2 ? Int64(parts[1])! * (parts[1].count == 1 ? 10 : 1) : 0
        let multiplied = whole.multipliedReportingOverflow(by: 100)
        let total = multiplied.partialValue.addingReportingOverflow(fraction)
        guard !multiplied.overflow, !total.overflow else { throw DomainError.invalidPrice }
        return total.partialValue
    }
    public static func price(_ cents: Int64?) -> String {
        guard let cents else { return "" }
        let remainder = cents % 100
        return "\(cents / 100).\(remainder < 10 ? "0" : "")\(remainder)"
    }

    private static func render(_ template: String, values: [String: String]) -> String {
        // Replace only tokens in the original template, not tokens in user-owned text.
        let pattern = try! NSRegularExpression(pattern: #"\{[a-z]+\}"#)
        let original = template as NSString
        let output = NSMutableString(string: template)
        for match in pattern.matches(in: template, range: NSRange(location: 0, length: original.length)).reversed() {
            if let value = values[original.substring(with: match.range)] { output.replaceCharacters(in: match.range, with: value) }
        }
        return output as String
    }
    public static func composeTitle(item: Item, template: String) -> String {
        render(template, values: ["{title}": item.title, "{category}": item.category ?? "Uncategorized"])
    }
    public static func composeDescription(item: Item, condition: ItemCondition?, rubric: RubricTemplate?, template: String) -> String {
        let valid = condition?.rubricID == rubric?.id && condition != nil
        let grade = valid ? ((try? rubric?.grade(condition!.answers)) ?? .unknown) : .unknown
        var checks: [String] = []
        var notes: [String] = []
        if valid, let condition, let rubric {
            for question in rubric.questions {
                let answer = condition.answers.first { $0.questionID == question.id }
                let note = answer?.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                checks.append("- \(question.displayTitle): \((answer?.value ?? .unknown).rawValue.capitalized)\(note.isEmpty ? "" : " (\(note))")")
                if !note.isEmpty { notes.append("• \(question.displayTitle): \(note)") }
            }
        }
        return render(template, values: ["{title}": item.title, "{category}": item.category ?? "Uncategorized",
            "{grade}": grade.rawValue.capitalized, "{checks}": checks.joined(separator: "\n"),
            "{notes}": notes.isEmpty ? "No notes recorded." : notes.joined(separator: "\n")])
    }
    /// The private minimum is deliberately not exported. Currency is user-selected externally.
    public static func shareExport(title: String, description: String, askingCents: Int64?) -> String {
        [title, description, askingCents.map { "Asking price: \(price($0)) (your currency)" } ?? "Asking price: Unknown"]
            .filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
