import Foundation
import Observation
import ResaleDeskKit
import ResaleDeskStore

@MainActor @Observable
final class InventoryModel {
    var items: [Item] = []
    var error: String?
    private var database: DeskDatabase?
    let root: URL

    init() {
        root = URL.applicationSupportDirectory.appendingPathComponent("ResaleDesk", isDirectory: true)
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset") {
                // Fresh-simulator launches have nothing to clear; missing root is fine.
                try? FileManager.default.removeItem(at: root)
            }
            #endif
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let store = try DeskDatabase(path: root.appendingPathComponent("desk.sqlite").path)
            let known = Set(try store.rubrics().map(\.id))
            for rubric in ResaleDeskKit.defaultRubrics where !known.contains(rubric.id) { try store.save(rubric) }
            database = store
            try reload()
        } catch { self.error = "Could not open local inventory: \(error.localizedDescription)" }
    }

    func reload() throws { items = try store().items() }
    func store() throws -> DeskDatabase {
        guard let database else { throw CocoaError(.fileReadUnknown) }
        return database
    }
    func save(_ item: Item) throws { try store().save(item); try reload() }
    func updateMetadata(itemID: String, title: String, category: String?) throws {
        try store().updateMetadata(itemID: itemID, title: title, category: category)
        try reload()
    }
    func condition(_ item: Item) throws -> ItemCondition? { try store().condition(itemID: item.id) }
    func rubrics() throws -> [RubricTemplate] { try store().rubrics() }
    func saveRubric(_ rubric: RubricTemplate) throws { try store().save(rubric) }
    func saveCondition(_ item: Item, rubric: RubricTemplate, answers: [ConditionAnswer]) throws {
        try store().save(rubric)
        try store().saveAnswers(itemID: item.id, rubricID: rubric.id, answers: answers)
    }
    func parcels() throws -> [Parcel] { try store().parcels() }
    func outcomes() throws -> [OutcomeEvent] { try store().outcomes() }
    func saveParcel(_ parcel: Parcel) throws { try store().save(parcel) }
    func packingEvents() throws -> [PackingEvent] { try store().packingEvents() }
    func recordPacking(parcelID: String, key: String, completed: Bool) throws {
        try store().append(PackingEvent(id: UUID().uuidString, parcelID: parcelID, checklistKey: key,
            completed: completed, recordedAt: Int64(Date().timeIntervalSince1970 * 1000)))
    }
    func recordOutcome(itemID: String, kind: OutcomeKind, netCents: Int64?, season: String) throws {
        try store().record(OutcomeEvent(id: UUID().uuidString, itemID: itemID, kind: kind, netCents: netCents, season: season))
    }
    func total(season: String) throws -> MoneyTotal { try store().total(season: season) }
    func draft(for item: Item) throws -> ListingDraft? { try store().drafts().first { $0.itemID == item.id } }
    func priceHistory(for item: Item) throws -> [PriceEvent] { try store().prices().filter { $0.itemID == item.id } }
    func rubric(for condition: ItemCondition) throws -> RubricTemplate? { try rubrics().first { $0.id == condition.rubricID } }
    func saveListing(_ draft: ListingDraft, askingCents: Int64?, minimumCents: Int64?) throws {
        try store().saveListing(draft, askingCents: askingCents, minimumCents: minimumCents,
            recordedAt: Int64(Date().timeIntervalSince1970 * 1000))
    }

    // Import is explicitly user initiated. Bytes stay under Application Support.
    func attach(_ data: Data, to item: Item) throws {
        guard !data.isEmpty, data.count <= 20 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let directory = root.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = "photos/\(UUID().uuidString).jpg"
        let url = root.appendingPathComponent(path)
        try data.write(to: url, options: .atomic)
        var updated = item
        updated.photoPaths.append(path)
        do {
            try store().save(updated)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        try reload()
    }
    func photoBytes(_ path: String, item: Item) throws -> Data {
        guard item.photoPaths.contains(path), !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let handle = try FileHandle(forReadingFrom: root.appendingPathComponent(path))
        defer { try? handle.close() }
        return try handle.readToEnd() ?? Data() // Only a validated sandbox file URL.
    }
    func detach(_ path: String, from item: Item) throws {
        var updated = item
        updated.photoPaths.removeAll { $0 == path }
        // Persist the manifest first; a failed write must not destroy evidence.
        try save(updated)
        try FileManager.default.removeItem(at: root.appendingPathComponent(path))
    }
}
