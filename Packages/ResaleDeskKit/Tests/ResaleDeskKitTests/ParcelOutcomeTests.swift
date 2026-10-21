import Foundation
import Testing
import ResaleDeskKit

@Suite struct ParcelOutcomeTests {
    @Test func packingChecklistStepsToggleDeterministically() {
        let parcelID = "p1"
        let events = [
            PackingEvent(id: "1", parcelID: parcelID, checklistKey: "condition-checked", completed: true, recordedAt: 10),
            PackingEvent(id: "2", parcelID: parcelID, checklistKey: "protected", completed: true, recordedAt: 20),
            PackingEvent(id: "3", parcelID: parcelID, checklistKey: "condition-checked", completed: false, recordedAt: 30),
            PackingEvent(id: "4", parcelID: parcelID, checklistKey: "sealed", completed: true, recordedAt: 40),
            PackingEvent(id: "5", parcelID: "other-parcel", checklistKey: "condition-checked", completed: true, recordedAt: 50),
        ]
        let done = PackingChecklist.completed(events, parcelID: parcelID)
        #expect(!done.contains("condition-checked"))
        #expect(done.contains("protected"))
        #expect(done.contains("sealed"))
        #expect(!done.contains("contents-checked"))
    }

    @Test func packingChecklistIgnoresUnknownKeys() {
        let events = [
            PackingEvent(id: "1", parcelID: "p", checklistKey: "custom-unsupported-step", completed: true, recordedAt: 10)
        ]
        #expect(PackingChecklist.completed(events, parcelID: "p").isEmpty)
    }

    @Test func outcomeKindsIncludeAllLifecycleStates() {
        let cases = Set(OutcomeKind.allCases.map(\.rawValue))
        #expect(cases.contains("sold"))
        #expect(cases.contains("returned"))
        #expect(cases.contains("donated"))
        #expect(cases.contains("discarded"))
        #expect(cases.contains("unsold"))
    }

    @Test func nonSaleOutcomesRejectNetCents() {
        for kind in [OutcomeKind.returned, .donated, .discarded, .unsold] {
            #expect(throws: DomainError.self) {
                try OutcomeEvent(id: "e", itemID: "i", kind: kind, netCents: 500, season: "2026").validate()
            }
            #expect(throws: Never.self) {
                try OutcomeEvent(id: "e", itemID: "i", kind: kind, netCents: nil, season: "2026").validate()
            }
        }
    }

    @Test func seasonTotalIncludesOnlySoldOutcomes() throws {
        let events = [
            OutcomeEvent(id: "1", itemID: "i1", kind: .sold, netCents: 1500, season: "2026"),
            OutcomeEvent(id: "2", itemID: "i2", kind: .donated, netCents: nil, season: "2026"),
            OutcomeEvent(id: "3", itemID: "i3", kind: .returned, netCents: nil, season: "2026"),
            OutcomeEvent(id: "4", itemID: "i4", kind: .discarded, netCents: nil, season: "2026"),
            OutcomeEvent(id: "5", itemID: "i5", kind: .sold, netCents: -200, season: "2026"), // recorded loss
            OutcomeEvent(id: "6", itemID: "i6", kind: .sold, netCents: 1000, season: "2025"), // wrong season
        ]
        #expect(try OutcomeEvent.total(events, season: "2026") == .known(1300))
    }

    @Test func seasonTotalWithMissingProceedsIsUnknown() throws {
        let events = [
            OutcomeEvent(id: "1", itemID: "i1", kind: .sold, netCents: 1500, season: "2026"),
            OutcomeEvent(id: "2", itemID: "i2", kind: .sold, netCents: nil, season: "2026"),
        ]
        #expect(try OutcomeEvent.total(events, season: "2026") == .unknown)
    }
}
