import Foundation
import GRDB
import Testing
import ResaleDeskKit
@testable import ResaleDeskStore

@Suite struct ListingStoreTests {
    @Test func draftAndChangedPricesSaveAtomically() throws {
        let store = try DeskDatabase()
        try store.save(Item(id: "i", title: "Book"))
        var draft = ListingDraft(id: "d", itemID: "i", title: "Copy", description: "Worn")
        try store.saveListing(draft, askingCents: 1200, minimumCents: 800, recordedAt: 5)
        try store.saveListing(draft, askingCents: 1200, minimumCents: 800, recordedAt: 6)
        #expect(try store.prices().count == 1)
        draft.description = "Revised"
        let nilPrice: Int64? = nil
        try store.saveListing(draft, askingCents: 1000, minimumCents: nilPrice, recordedAt: 4)
        #expect(try store.prices().map(\.askingCents) == [1200, 1000])
        #expect(try store.prices().last?.recordedAt == 5)
        try store.saveListing(draft, askingCents: nilPrice, minimumCents: nilPrice, recordedAt: 8)
        #expect(try store.prices().last?.askingCents == nil)
        #expect(try store.drafts() == [draft])
        let old = draft
        draft.description = "Must roll back"
        try store.queue.write { try $0.execute(sql: "CREATE TRIGGER reject_price BEFORE INSERT ON price BEGIN SELECT RAISE(ABORT, 'disk failure'); END") }
        #expect(throws: (any Error).self) { try store.saveListing(draft, askingCents: 500, minimumCents: nilPrice, recordedAt: 9) }
        #expect(try store.drafts() == [old])
        #expect(try store.prices().count == 3)
        #expect(throws: DomainError.self) { try store.saveListing(draft, askingCents: 100, minimumCents: 200, recordedAt: 9) }
        #expect(try store.drafts() == [old])
    }
}
