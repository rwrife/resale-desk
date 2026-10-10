import Foundation
import Testing
@testable import ResaleDeskKit

@Suite("Condition and ledger invariants")
struct DomainTests {
    let template = RubricTemplate(id: "apparel", questions: [
        RubricQuestion(id: "stains", required: true),
        RubricQuestion(id: "seams", required: true),
        RubricQuestion(id: "tag", required: false),
    ])

    @Test func incompleteAndUnknownAreNeverGraded() throws {
        #expect(try template.grade([ConditionAnswer(questionID: "stains", value: .pass)]) == .unknown)
        #expect(try template.grade([ConditionAnswer(questionID: "stains", value: .unknown), ConditionAnswer(questionID: "seams", value: .pass)]) == .unknown)
    }

    @Test func completeAnswersProduceDeterministicGrade() throws {
        #expect(try template.grade([ConditionAnswer(questionID: "stains", value: .pass), ConditionAnswer(questionID: "seams", value: .pass)]) == .excellent)
        #expect(try template.grade([ConditionAnswer(questionID: "stains", value: .fail), ConditionAnswer(questionID: "seams", value: .pass)]) == .good)
        #expect(try template.grade([ConditionAnswer(questionID: "stains", value: .fail), ConditionAnswer(questionID: "seams", value: .fail)]) == .fair)
    }

    @Test func rubricRejectsInvalidAnswersAndDefinition() throws {
        #expect(throws: DomainError.self) { try RubricTemplate(id: "", questions: []).validate() }
        #expect(throws: DomainError.self) { try RubricTemplate(id: "x", questions: [RubricQuestion(id: "a", required: true), RubricQuestion(id: "a", required: true)]).validate() }
        #expect(throws: DomainError.self) { try RubricTemplate(id: "x", questions: [RubricQuestion(id: "a", required: false)]).validate() }
        #expect(throws: DomainError.self) { try RubricTemplate(id: "x", questions: [RubricQuestion(id: " ", required: true)]).validate() }
        #expect(throws: DomainError.self) { try template.grade([ConditionAnswer(questionID: "other", value: .pass)]) }
        #expect(throws: DomainError.self) { try template.grade([ConditionAnswer(questionID: "stains", value: .pass), ConditionAnswer(questionID: "stains", value: .fail)]) }
    }

    @Test func moneyTotalsPropagateUnknownAndRejectInvalidSale() throws {
        let known = OutcomeEvent(id: "a", itemID: "item", kind: .sold, netCents: 1200, season: "2026")
        let unknown = OutcomeEvent(id: "b", itemID: "item2", kind: .sold, netCents: nil, season: "2026")
        let other = OutcomeEvent(id: "c", itemID: "item3", kind: .sold, netCents: 400, season: "2025")
        #expect(try OutcomeEvent.total([known, other], season: "2026") == .known(1200))
        #expect(try OutcomeEvent.total([known, unknown], season: "2026") == .unknown)
        #expect(try OutcomeEvent.total([], season: "2026") == .known(0))
        #expect(throws: DomainError.self) { try OutcomeEvent(id: "x", itemID: "item", kind: .unsold, netCents: 100, season: "2026").validate() }
        #expect(throws: DomainError.self) { try OutcomeEvent.total([known], season: " ") }
        #expect(throws: DomainError.self) { try OutcomeEvent.total([known, known], season: "2026") }
        #expect(throws: DomainError.self) { try OutcomeEvent.total([known, OutcomeEvent(id: "z", itemID: "item", kind: .sold, netCents: 10, season: "2026")], season: "2026") }
        #expect(throws: DomainError.self) { try OutcomeEvent.total([OutcomeEvent(id: "max", itemID: "m", kind: .sold, netCents: .max, season: "2026"), known], season: "2026") }
        #expect(try OutcomeEvent.total([OutcomeEvent(id: "d", itemID: "gift", kind: .donated, netCents: nil, season: "2026")], season: "2026") == .known(0))
    }

    @Test func priceHistoryCannotRewriteOrUseNegativePrices() throws {
        let first = PriceEvent(id: "p1", itemID: "i", askingCents: 100, minimumCents: 50, recordedAt: 1)
        let next = PriceEvent(id: "p2", itemID: "i", askingCents: 90, minimumCents: nil, recordedAt: 2)
        #expect(try PriceEvent.validateHistory([first, next]).count == 2)
        #expect(throws: DomainError.self) { try PriceEvent.validateHistory([next, first]) }
        #expect(throws: DomainError.self) { try PriceEvent.validateHistory([first, first]) }
        #expect(throws: DomainError.self) { try PriceEvent(id: "bad", itemID: "i", askingCents: -1, minimumCents: nil, recordedAt: 1).validate() }
        #expect(throws: DomainError.self) { try PriceEvent(id: "bad", itemID: "i", askingCents: 50, minimumCents: 60, recordedAt: 1).validate() }
        #expect(throws: DomainError.self) { try PriceEvent(id: "bad", itemID: "i", askingCents: nil, minimumCents: -1, recordedAt: 1).validate() }
        #expect(throws: DomainError.self) { try PriceEvent(id: "bad", itemID: "i", askingCents: nil, minimumCents: nil, recordedAt: -1).validate() }
        try PriceEvent(id: "unknown", itemID: "i", askingCents: nil, minimumCents: nil, recordedAt: 0).validate()
    }

    @Test func addedOptionalFieldsDecodeFromOlderLocalRecords() throws {
        let decoder = JSONDecoder()
        let item = try decoder.decode(Item.self, from: Data(#"{"id":"i","title":"Book","photoPaths":[]}"#.utf8))
        let question = try decoder.decode(RubricQuestion.self, from: Data(#"{"id":"spine","required":true}"#.utf8))
        let answer = try decoder.decode(ConditionAnswer.self, from: Data(#"{"questionID":"spine","value":"fail"}"#.utf8))
        #expect(item.category == nil)
        #expect(question.displayTitle == "spine")
        #expect(answer.note == nil)
        #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    }

    @Test func parcelAndDraftValidateReferences() throws {
        #expect(throws: DomainError.self) { try Item(id: "", title: "Book").validate() }
        #expect(throws: DomainError.self) { try Item(id: "i", title: "Book", photoPaths: ["photos/a.jpg", "photos/a.jpg"]).validate() }
        #expect(throws: DomainError.self) { try Item(id: "i", title: "Book", photoPaths: ["/absolute.jpg"]).validate() }
        #expect(throws: DomainError.self) { try Item(id: "i", title: "Book", photoPaths: ["../escape.jpg"]).validate() }
        #expect(throws: DomainError.self) { try Item(id: "i", title: "Book", photoPaths: [""]).validate() }
        try Item(id: "i", title: "Book", photoPaths: ["photos/1.jpg", "photos/2.jpg"]).validate()
        #expect(throws: DomainError.self) { try ListingDraft(id: "d", itemID: "", title: "", description: "").validate() }
        #expect(throws: DomainError.self) { try ListingDraft(id: "", itemID: "i", title: "", description: "").validate() }
        try ListingDraft(id: "d", itemID: "i", title: "", description: "").validate()
        #expect(throws: DomainError.self) { try Parcel(id: "p", itemIDs: ["a", "a"]).validate() }
        #expect(throws: DomainError.self) { try Parcel(id: "p", itemIDs: []).validate() }
        #expect(throws: DomainError.self) { try Parcel(id: "p", itemIDs: [" "]).validate() }
        try Parcel(id: "p", itemIDs: ["a", "b"]).validate()
        #expect(throws: DomainError.self) { try PackingEvent(id: "e", parcelID: "p", checklistKey: "", completed: true, recordedAt: 1).validate() }
        #expect(throws: DomainError.self) { try PackingEvent(id: "e", parcelID: "p", checklistKey: "wrap", completed: true, recordedAt: -1).validate() }
        try PackingEvent(id: "e", parcelID: "p", checklistKey: "wrap", completed: true, recordedAt: 0).validate()
    }
}
