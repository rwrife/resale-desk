import Foundation

public enum DomainError: Error, Equatable { case invalidIdentity, invalidRubric, invalidAnswers, invalidPrice, invalidHistory, invalidParcel, invalidOutcome, overflow }

private func identity(_ values: String...) throws {
    guard values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw DomainError.invalidIdentity }
}

public struct Item: Codable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var photoPaths: [String]
    public var category: String?
    public init(id: String, title: String, photoPaths: [String] = [], category: String? = nil) {
        self.id = id; self.title = title; self.photoPaths = photoPaths; self.category = category
    }
    // Backward-compatible with M2 JSON fixtures and local databases lacking category.
    private enum CodingKeys: String, CodingKey { case id, title, photoPaths, category }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        photoPaths = try values.decode([String].self, forKey: .photoPaths)
        category = try values.decodeIfPresent(String.self, forKey: .category)
    }
    public func validate() throws {
        try identity(id, title)
        guard Set(photoPaths).count == photoPaths.count, photoPaths.allSatisfy({ !$0.isEmpty && !$0.hasPrefix("/") && !$0.split(separator: "/").contains("..") }) else { throw DomainError.invalidIdentity }
    }
}

public enum CheckValue: String, Codable, Sendable, CaseIterable { case pass, fail, unknown }
public enum ConditionGrade: String, Codable, Sendable { case excellent, good, fair, unknown }
public struct RubricQuestion: Codable, Equatable, Sendable {
    public let id: String
    public let title: String?
    public let required: Bool
    public init(id: String, title: String? = nil, required: Bool) { self.id = id; self.title = title; self.required = required }
    private enum CodingKeys: String, CodingKey { case id, title, required }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        required = try values.decode(Bool.self, forKey: .required)
    }
    /// Display label for capture UIs; falls back to a humanized id.
    public var displayTitle: String { title ?? id.replacingOccurrences(of: "-", with: " ") }
}
public struct ConditionAnswer: Codable, Equatable, Sendable {
    public let questionID: String
    public let value: CheckValue
    /// Optional free-text note (e.g. defect description). Never affects grade derivation.
    public var note: String?
    public init(questionID: String, value: CheckValue, note: String? = nil) { self.questionID = questionID; self.value = value; self.note = note }
    private enum CodingKeys: String, CodingKey { case questionID, value, note }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        questionID = try values.decode(String.self, forKey: .questionID)
        value = try values.decode(CheckValue.self, forKey: .value)
        note = try values.decodeIfPresent(String.self, forKey: .note)
    }
}
public struct ItemCondition: Codable, Equatable, Sendable {
    public let rubricID: String
    public let answers: [ConditionAnswer]
    public init(rubricID: String, answers: [ConditionAnswer]) { self.rubricID = rubricID; self.answers = answers }
    public func validate() throws { try identity(rubricID) }
}
public struct RubricTemplate: Codable, Equatable, Sendable {
    public let id: String
    public let questions: [RubricQuestion]
    public init(id: String, questions: [RubricQuestion]) { self.id = id; self.questions = questions }
    public func validate() throws {
        try identity(id)
        guard questions.contains(where: \.required), Set(questions.map(\.id)).count == questions.count,
              questions.allSatisfy({ !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw DomainError.invalidRubric }
    }
    /// Grade is a local checklist summary, not an appraisal. Optional checks do not affect it.
    public func grade(_ answers: [ConditionAnswer]) throws -> ConditionGrade {
        try validate()
        guard Set(answers.map(\.questionID)).count == answers.count,
              answers.allSatisfy({ answer in questions.contains { $0.id == answer.questionID } }) else { throw DomainError.invalidAnswers }
        let required = questions.filter(\.required).map { q in answers.first { $0.questionID == q.id }?.value }
        guard required.allSatisfy({ $0 != nil && $0 != .unknown }) else { return .unknown }
        let failures = required.filter { $0 == .fail }.count
        return failures == 0 ? .excellent : failures == 1 ? .good : .fair
    }
}

public struct ListingDraft: Codable, Equatable, Sendable {
    public let id: String
    public let itemID: String
    public var title: String
    public var description: String
    public init(id: String, itemID: String, title: String, description: String) { self.id = id; self.itemID = itemID; self.title = title; self.description = description }
    public func validate() throws {
        try identity(id, itemID)
    }
}

public struct PriceEvent: Codable, Equatable, Sendable {
    public let id: String
    public let itemID: String
    public let askingCents: Int64?
    public let minimumCents: Int64?
    public let recordedAt: Int64
    public init(id: String, itemID: String, askingCents: Int64?, minimumCents: Int64?, recordedAt: Int64) {
        self.id = id; self.itemID = itemID; self.askingCents = askingCents; self.minimumCents = minimumCents; self.recordedAt = recordedAt
    }
    public func validate() throws {
        try identity(id, itemID)
        guard recordedAt >= 0, askingCents.map({ $0 >= 0 }) ?? true, minimumCents.map({ $0 >= 0 }) ?? true else { throw DomainError.invalidPrice }
        if let askingCents, let minimumCents, minimumCents > askingCents { throw DomainError.invalidPrice }
    }
    @discardableResult public static func validateHistory(_ events: [PriceEvent]) throws -> [PriceEvent] {
        var ids = Set<String>(); var last: [String: Int64] = [:]
        for e in events {
            try e.validate()
            guard ids.insert(e.id).inserted, last[e.itemID].map({ e.recordedAt >= $0 }) ?? true else { throw DomainError.invalidHistory }
            last[e.itemID] = e.recordedAt
        }
        return events
    }
}

public struct Parcel: Codable, Equatable, Sendable {
    public let id: String
    public var itemIDs: [String]
    public var carrier: String
    public var tracking: String
    public init(id: String, itemIDs: [String], carrier: String = "", tracking: String = "") { self.id = id; self.itemIDs = itemIDs; self.carrier = carrier; self.tracking = tracking }
    public func validate() throws {
        try identity(id)
        guard !itemIDs.isEmpty, Set(itemIDs).count == itemIDs.count, itemIDs.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw DomainError.invalidParcel }
    }
}
public struct PackingEvent: Codable, Equatable, Sendable {
    public let id: String
    public let parcelID: String
    public let checklistKey: String
    public let completed: Bool
    public let recordedAt: Int64
    public init(id: String, parcelID: String, checklistKey: String, completed: Bool, recordedAt: Int64) { self.id = id; self.parcelID = parcelID; self.checklistKey = checklistKey; self.completed = completed; self.recordedAt = recordedAt }
    public func validate() throws { try identity(id, parcelID, checklistKey); guard recordedAt >= 0 else { throw DomainError.invalidHistory } }
}

public enum OutcomeKind: String, Codable, Sendable { case sold, unsold, donated }
public enum MoneyTotal: Equatable, Sendable { case known(Int64), unknown }
public struct OutcomeEvent: Codable, Equatable, Sendable {
    public let id: String
    public let itemID: String
    public let kind: OutcomeKind
    /// Signed net cents: negative net proceeds represent a recorded loss, not an invalid price.
    public let netCents: Int64?
    public let season: String
    public init(id: String, itemID: String, kind: OutcomeKind, netCents: Int64?, season: String) { self.id = id; self.itemID = itemID; self.kind = kind; self.netCents = netCents; self.season = season }
    public func validate() throws {
        try identity(id, itemID, season)
        guard kind == .sold || netCents == nil else { throw DomainError.invalidOutcome }
    }
    public static func total(_ events: [OutcomeEvent], season: String) throws -> MoneyTotal {
        try identity(season)
        var ids = Set<String>(); var items = Set<String>(); var sum: Int64 = 0; var missing = false
        for e in events {
            try e.validate()
            guard ids.insert(e.id).inserted, items.insert(e.itemID).inserted else { throw DomainError.invalidOutcome }
            guard e.season == season, e.kind == .sold else { continue }
            guard let amount = e.netCents else { missing = true; continue }
            let result = sum.addingReportingOverflow(amount)
            guard !result.overflow else { throw DomainError.overflow }
            sum = result.partialValue
        }
        return missing ? .unknown : .known(sum)
    }
}
