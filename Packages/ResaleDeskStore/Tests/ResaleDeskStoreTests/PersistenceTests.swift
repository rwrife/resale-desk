import Foundation
import GRDB
import Testing
import ResaleDeskKit
@testable import ResaleDeskStore

@Suite struct PersistenceTests {
    @Test func roundTripAllEntitiesAndUnknownTotals() throws {
        let store = try DeskDatabase()
        let item = Item(id: "i", title: "Book", photoPaths: ["photos/book.jpg"])
        try store.save(item)
        let rubric = RubricTemplate(id: "r", questions: [RubricQuestion(id: "pages", required: true)])
        try store.save(rubric)
        try store.saveAnswers(itemID: "i", rubricID: "r", answers: [ConditionAnswer(questionID: "pages", value: .unknown)])
        try store.save(ListingDraft(id: "d", itemID: "i", title: "Book", description: "Worn spine"))
        try store.save(Parcel(id: "p", itemIDs: ["i"], carrier: "Manual", tracking: "Private"))
        try store.append(PackingEvent(id: "pack", parcelID: "p", checklistKey: "wrap", completed: true, recordedAt: 1))
        try store.append(PriceEvent(id: "price", itemID: "i", askingCents: 500, minimumCents: nil, recordedAt: 1))
        try store.append(OutcomeEvent(id: "out", itemID: "i", kind: .sold, netCents: nil, season: "2026"))
        #expect(try store.items() == [item])
        #expect(try store.rubrics() == [rubric])
        #expect(try store.grade(itemID: "i") == .unknown)
        #expect(try store.drafts().first?.description == "Worn spine")
        #expect(try store.parcels().first?.tracking == "Private")
        #expect(try store.packingEvents().first?.completed == true)
        #expect(try store.prices().first?.askingCents == 500)
        #expect(try store.total(season: "2026") == .unknown)
        #expect(throws: StoreError.self) { try store.append(PriceEvent(id: "late", itemID: "i", askingCents: 100, minimumCents: nil, recordedAt: 2)) }
    }

    @Test func invalidWritesRollbackAndHistoryCannotBeMutated() throws {
        let store = try DeskDatabase()
        try store.save(Item(id: "i", title: "Book"))
        try store.append(PriceEvent(id: "p", itemID: "i", askingCents: nil, minimumCents: nil, recordedAt: 2))
        #expect(throws: DomainError.self) { try store.append(PriceEvent(id: "old", itemID: "i", askingCents: 1, minimumCents: nil, recordedAt: 1)) }
        #expect(throws: (any Error).self) { try store.append(PriceEvent(id: "p", itemID: "i", askingCents: 1, minimumCents: nil, recordedAt: 3)) }
        #expect(throws: (any Error).self) { try store.save(ListingDraft(id: "d", itemID: "missing", title: "", description: "")) }
        #expect(throws: (any Error).self) { try store.save(Parcel(id: "bad", itemIDs: ["i", "missing"])) }
        #expect(try store.parcels().isEmpty)
        #expect(throws: (any Error).self) { try store.append(PackingEvent(id: "bad", parcelID: "missing", checklistKey: "wrap", completed: true, recordedAt: 1)) }
        try store.append(OutcomeEvent(id: "o", itemID: "i", kind: .sold, netCents: -20, season: "2026"))
        #expect(try store.total(season: "2026") == .known(-20))
        #expect(throws: StoreError.self) { try store.append(OutcomeEvent(id: "o2", itemID: "i", kind: .donated, netCents: nil, season: "2026")) }
        try store.save(Parcel(id: "parcel", itemIDs: ["i"]))
        try store.append(PackingEvent(id: "packing", parcelID: "parcel", checklistKey: "wrap", completed: true, recordedAt: 1))
        for table in ["price", "outcome", "packing"] {
            #expect(throws: (any Error).self) { try store.queue.write { try $0.execute(sql: "UPDATE \(table) SET payload = '{}' ") } }
            #expect(throws: (any Error).self) { try store.queue.write { try $0.execute(sql: "DELETE FROM \(table)") } }
        }
        #expect(try store.prices().count == 1)
        #expect(try store.outcomes().count == 1)
        #expect(try store.packingEvents().count == 1)
        #expect(throws: StoreError.self) { try store.save(Parcel(id: "parcel", itemIDs: ["i", "other"])) }
    }

    @Test func conditionReferencesAndUpdatesRemainValid() throws {
        let store = try DeskDatabase()
        try store.save(Item(id: "i", title: "Book"))
        #expect(try store.grade(itemID: "i") == .unknown)
        let r = RubricTemplate(id: "r", questions: [RubricQuestion(id: "pages", required: true)])
        try store.save(r)
        #expect(throws: (any Error).self) { try store.saveAnswers(itemID: "missing", rubricID: "r", answers: []) }
        #expect(throws: StoreError.self) { try store.saveAnswers(itemID: "i", rubricID: "missing", answers: []) }
        #expect(throws: DomainError.self) { try store.saveAnswers(itemID: "i", rubricID: "r", answers: [ConditionAnswer(questionID: "other", value: .pass)]) }
        try store.saveAnswers(itemID: "i", rubricID: "r", answers: [ConditionAnswer(questionID: "pages", value: .pass)])
        #expect(try store.grade(itemID: "i") == .excellent)
        #expect(throws: StoreError.self) { try store.save(RubricTemplate(id: "r", questions: [RubricQuestion(id: "new", required: true)])) }
        try store.queue.write { try $0.execute(sql: "UPDATE condition SET payload = '[]' WHERE itemID = 'i'") }
        #expect(try store.grade(itemID: "i") == .unknown)
        try store.save(Item(id: "i", title: "Edited"))
        #expect(try store.items().first?.title == "Edited")
    }

    @Test func v1FixtureMigratesReopensAndPreservesLedger() throws {
        let source = try #require(Bundle.module.url(forResource: "v1", withExtension: "sqlite", subdirectory: "Fixtures"))
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        try FileManager.default.copyItem(atPath: source.path, toPath: path)
        do {
            let store = try DeskDatabase(path: path)
            #expect(try store.items() == [Item(id: "fixture-item", title: "Fixture book")])
            #expect(try store.prices().first?.askingCents == 1200)
            #expect(try store.total(season: "2026") == .unknown)
            #expect(try store.queue.read { try String.fetchAll($0, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier") } == ["v1", "v2-ledger-guards"])
            try store.save(Item(id: "second", title: "Added after migration"))
            try store.append(OutcomeEvent(id: "second-sale", itemID: "second", kind: .sold, netCents: 500, season: "2026"))
            try store.queue.close()
        }
        let reopened = try DeskDatabase(path: path)
        #expect(try reopened.items().count == 2)
        #expect(try reopened.outcomes().count == 2)
        #expect(try reopened.total(season: "2026") == .unknown)
        #expect(throws: (any Error).self) { try reopened.queue.write { try $0.execute(sql: "DELETE FROM outcome") } }
        try reopened.queue.close()
    }
}
