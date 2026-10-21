import Foundation
import Testing
import ResaleDeskKit
@testable import ResaleDeskStore

@Suite struct ParcelOutcomeStoreTests {
    @Test func parcelChecklistAndCarrierRoundTrip() throws {
        let store = try DeskDatabase()
        try store.save(Item(id: "i1", title: "Camera"))
        try store.save(Item(id: "i2", title: "Lens"))
        try store.save(Parcel(id: "p", itemIDs: ["i1", "i2"]))
        #expect(try store.parcels().first?.itemIDs.count == 2)
        #expect(try store.parcelChecklist(parcelID: "p").isEmpty)
        try store.append(PackingEvent(id: "e1", parcelID: "p", checklistKey: "condition-checked", completed: true, recordedAt: 1))
        try store.append(PackingEvent(id: "e2", parcelID: "p", checklistKey: "condition-checked", completed: false, recordedAt: 2))
        try store.append(PackingEvent(id: "e3", parcelID: "p", checklistKey: "protected", completed: true, recordedAt: 3))
        #expect(try store.parcelChecklist(parcelID: "p") == Set(["protected"]))
        try store.save(Parcel(id: "p", itemIDs: ["i1", "i2"], carrier: "Manual", tracking: "ABC123"))
        #expect(try store.parcels().first?.carrier == "Manual")
        #expect(try store.parcels().first?.tracking == "ABC123")
        #expect(try store.packingEvents().count == 3)
    }

    @Test func parcelCannotClaimItemsAlreadyInOtherParcels() throws {
        let store = try DeskDatabase()
        try store.save(Item(id: "i", title: "Book"))
        try store.save(Parcel(id: "p1", itemIDs: ["i"]))
        #expect(throws: StoreError.self) { try store.save(Parcel(id: "p2", itemIDs: ["i"])) }
        #expect(try store.parcels().count == 1)
    }

    @Test func outcomeClosesItemAndKeepsHistoryAppendOnly() throws {
        let store = try DeskDatabase()
        try store.save(Item(id: "i", title: "Book"))
        try store.record(OutcomeEvent(id: "o1", itemID: "i", kind: .sold, netCents: nil, season: "2026"))
        #expect(try store.outcome(itemID: "i")?.kind == .sold)
        #expect(try store.total(season: "2026") == .unknown)
        #expect(throws: StoreError.self) { try store.record(OutcomeEvent(id: "o2", itemID: "i", kind: .donated, netCents: nil, season: "2026")) }
        #expect(throws: StoreError.self) { try store.append(PriceEvent(id: "price", itemID: "i", askingCents: 500, minimumCents: nil, recordedAt: 1)) }
        #expect(throws: StoreError.self) { try store.save(ListingDraft(id: "draft", itemID: "i", title: "Closed", description: "")) }
        #expect(try store.outcomes().count == 1)
    }

    @Test func nonSaleOutcomeHasNoMoneyAndDoesNotAffectTotals() throws {
        let store = try DeskDatabase()
        try store.save(Item(id: "i", title: "Book"))
        try store.record(OutcomeEvent(id: "o1", itemID: "i", kind: .returned, netCents: nil, season: "2026"))
        #expect(try store.total(season: "2026") == .known(0))
        #expect(try store.outcomes().first?.kind == .returned)
    }
}
