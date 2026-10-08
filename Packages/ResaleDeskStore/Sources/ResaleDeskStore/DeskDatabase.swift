import Foundation
import GRDB
import ResaleDeskKit

public enum StoreError: Error { case missingRubric, referencedRubric, terminalItem, corruptPayload, packedParcel }

/// Synchronous local store. GRDB serializes writes; every multi-row operation is atomic.
public final class DeskDatabase {
    let queue: DatabaseQueue
    public init(path: String = ":memory:") throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        queue = try DatabaseQueue(path: path, configuration: config)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { try $0.execute(sql: Self.v1SQL) }
        migrator.registerMigration("v2-ledger-guards") { db in
            for table in ["price", "outcome", "packing"] {
                for operation in ["UPDATE", "DELETE"] {
                    try db.execute(sql: "CREATE TRIGGER \(table)_no_\(operation.lowercased()) BEFORE \(operation) ON \(table) BEGIN SELECT RAISE(ABORT, 'append-only ledger'); END")
                }
            }
            try db.execute(sql: "CREATE INDEX price_item_time ON price(itemID, recordedAt); CREATE INDEX packing_parcel_time ON packing(parcelID, recordedAt)")
        }
        try migrator.migrate(queue)
    }

    static let v1SQL = """
        CREATE TABLE item (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL);
        CREATE TABLE rubric (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL);
        CREATE TABLE condition (itemID TEXT PRIMARY KEY NOT NULL REFERENCES item(id) ON DELETE RESTRICT,
            rubricID TEXT NOT NULL REFERENCES rubric(id) ON DELETE RESTRICT, payload TEXT NOT NULL);
        CREATE TABLE draft (id TEXT PRIMARY KEY NOT NULL, itemID TEXT NOT NULL UNIQUE REFERENCES item(id) ON DELETE RESTRICT, payload TEXT NOT NULL);
        CREATE TABLE parcel (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL);
        CREATE TABLE parcel_item (parcelID TEXT NOT NULL REFERENCES parcel(id) ON DELETE RESTRICT,
            itemID TEXT NOT NULL REFERENCES item(id) ON DELETE RESTRICT, PRIMARY KEY(parcelID, itemID));
        CREATE TABLE packing (id TEXT PRIMARY KEY NOT NULL, parcelID TEXT NOT NULL REFERENCES parcel(id) ON DELETE RESTRICT,
            recordedAt INTEGER NOT NULL CHECK(recordedAt >= 0), payload TEXT NOT NULL);
        CREATE TABLE price (id TEXT PRIMARY KEY NOT NULL, itemID TEXT NOT NULL REFERENCES item(id) ON DELETE RESTRICT,
            recordedAt INTEGER NOT NULL CHECK(recordedAt >= 0), payload TEXT NOT NULL);
        CREATE TABLE outcome (id TEXT PRIMARY KEY NOT NULL, itemID TEXT NOT NULL UNIQUE REFERENCES item(id) ON DELETE RESTRICT, payload TEXT NOT NULL);
        """

    private static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
    private static func decode<T: Decodable>(_ type: T.Type, _ row: Row) throws -> T {
        let text: String = row["payload"]
        return try JSONDecoder().decode(type, from: Data(text.utf8))
    }
    private static func check(_ value: String, _ row: Row, column: String = "id") throws {
        guard value == row[column] as String else { throw StoreError.corruptPayload }
    }
    private static func active(_ id: String, _ db: Database) throws {
        guard try Row.fetchOne(db, sql: "SELECT id FROM outcome WHERE itemID = ?", arguments: [id]) == nil else { throw StoreError.terminalItem }
    }

    public func save(_ item: Item) throws {
        try item.validate()
        try queue.write { db in
            try db.execute(sql: "INSERT INTO item VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload", arguments: [item.id, try Self.encode(item)])
        }
    }
    public func save(_ rubric: RubricTemplate) throws {
        try rubric.validate()
        try queue.write { db in
            if let row = try Row.fetchOne(db, sql: "SELECT * FROM rubric WHERE id = ?", arguments: [rubric.id]),
               try Self.decode(RubricTemplate.self, row) != rubric,
               try Row.fetchOne(db, sql: "SELECT itemID FROM condition WHERE rubricID = ?", arguments: [rubric.id]) != nil {
                throw StoreError.referencedRubric
            }
            try db.execute(sql: "INSERT INTO rubric VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload", arguments: [rubric.id, try Self.encode(rubric)])
        }
    }
    public func saveAnswers(itemID: String, rubricID: String, answers: [ConditionAnswer]) throws {
        try queue.write { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM rubric WHERE id = ?", arguments: [rubricID]) else { throw StoreError.missingRubric }
            let rubric = try Self.decode(RubricTemplate.self, row)
            try Self.check(rubric.id, row)
            _ = try rubric.grade(answers)
            try db.execute(sql: "INSERT INTO condition VALUES (?, ?, ?) ON CONFLICT(itemID) DO UPDATE SET rubricID = excluded.rubricID, payload = excluded.payload", arguments: [itemID, rubricID, try Self.encode(answers)])
        }
    }
    public func grade(itemID: String) throws -> ConditionGrade {
        try queue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM condition WHERE itemID = ?", arguments: [itemID]) else { return .unknown }
            let rubricID: String = row["rubricID"]
            guard let templateRow = try Row.fetchOne(db, sql: "SELECT * FROM rubric WHERE id = ?", arguments: [rubricID]) else { throw StoreError.missingRubric }
            let template = try Self.decode(RubricTemplate.self, templateRow)
            try Self.check(template.id, templateRow)
            return try template.grade(Self.decode([ConditionAnswer].self, row))
        }
    }
    public func save(_ draft: ListingDraft) throws {
        try draft.validate()
        try queue.write { db in
            try Self.active(draft.itemID, db)
            try db.execute(sql: "INSERT INTO draft VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET itemID = excluded.itemID, payload = excluded.payload", arguments: [draft.id, draft.itemID, try Self.encode(draft)])
        }
    }
    public func save(_ parcel: Parcel) throws {
        try parcel.validate()
        try queue.write { db in
            if let row = try Row.fetchOne(db, sql: "SELECT * FROM parcel WHERE id = ?", arguments: [parcel.id]),
               try Self.decode(Parcel.self, row).itemIDs != parcel.itemIDs,
               try Row.fetchOne(db, sql: "SELECT id FROM packing WHERE parcelID = ?", arguments: [parcel.id]) != nil { throw StoreError.packedParcel }
            try db.execute(sql: "INSERT INTO parcel VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload", arguments: [parcel.id, try Self.encode(parcel)])
            try db.execute(sql: "DELETE FROM parcel_item WHERE parcelID = ?", arguments: [parcel.id])
            for itemID in parcel.itemIDs {
                try db.execute(sql: "INSERT INTO parcel_item VALUES (?, ?)", arguments: [parcel.id, itemID])
            }
        }
    }
    public func append(_ price: PriceEvent) throws {
        try price.validate()
        try queue.write { db in
            try Self.active(price.itemID, db)
            let prior = try Self.prices(db).filter { $0.itemID == price.itemID }
            try PriceEvent.validateHistory(prior + [price])
            try db.execute(sql: "INSERT INTO price VALUES (?, ?, ?, ?)", arguments: [price.id, price.itemID, price.recordedAt, try Self.encode(price)])
        }
    }
    public func append(_ event: OutcomeEvent) throws {
        try event.validate()
        try queue.write { db in
            try Self.active(event.itemID, db)
            try db.execute(sql: "INSERT INTO outcome VALUES (?, ?, ?)", arguments: [event.id, event.itemID, try Self.encode(event)])
        }
    }
    public func append(_ event: PackingEvent) throws {
        try event.validate()
        try queue.write { db in
            let latest = try Int64.fetchOne(db, sql: "SELECT MAX(recordedAt) FROM packing WHERE parcelID = ?", arguments: [event.parcelID])
            guard latest.map({ event.recordedAt >= $0 }) ?? true else { throw DomainError.invalidHistory }
            try db.execute(sql: "INSERT INTO packing VALUES (?, ?, ?, ?)", arguments: [event.id, event.parcelID, event.recordedAt, try Self.encode(event)])
        }
    }
    public func items() throws -> [Item] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY id").map { row in
                let value = try Self.decode(Item.self, row); try value.validate(); try Self.check(value.id, row); return value
            }
        }
    }
    public func rubrics() throws -> [RubricTemplate] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM rubric ORDER BY id").map { row in
                let value = try Self.decode(RubricTemplate.self, row); try value.validate(); try Self.check(value.id, row); return value
            }
        }
    }
    public func drafts() throws -> [ListingDraft] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM draft ORDER BY id").map { row in
                let value = try Self.decode(ListingDraft.self, row); try value.validate(); try Self.check(value.id, row); try Self.check(value.itemID, row, column: "itemID"); return value
            }
        }
    }
    public func parcels() throws -> [Parcel] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM parcel ORDER BY id").map { row in
                let value = try Self.decode(Parcel.self, row); try value.validate(); try Self.check(value.id, row)
                let ids = try String.fetchAll(db, sql: "SELECT itemID FROM parcel_item WHERE parcelID = ? ORDER BY itemID", arguments: [value.id])
                guard ids == value.itemIDs.sorted() else { throw StoreError.corruptPayload }; return value
            }
        }
    }
    private static func prices(_ db: Database) throws -> [PriceEvent] {
        try Row.fetchAll(db, sql: "SELECT * FROM price ORDER BY recordedAt, rowid").map { row in
            let value = try decode(PriceEvent.self, row); try value.validate(); try check(value.id, row); try check(value.itemID, row, column: "itemID")
            guard value.recordedAt == row["recordedAt"] as Int64 else { throw StoreError.corruptPayload }; return value
        }
    }
    public func prices() throws -> [PriceEvent] { try queue.read { try Self.prices($0) } }
    private static func outcomes(_ db: Database) throws -> [OutcomeEvent] {
        try Row.fetchAll(db, sql: "SELECT * FROM outcome ORDER BY rowid").map { row in
            let value = try decode(OutcomeEvent.self, row); try value.validate(); try check(value.id, row); try check(value.itemID, row, column: "itemID"); return value
        }
    }
    public func outcomes() throws -> [OutcomeEvent] { try queue.read { try Self.outcomes($0) } }
    public func total(season: String) throws -> MoneyTotal { try queue.read { try OutcomeEvent.total(Self.outcomes($0), season: season) } }
    public func packingEvents() throws -> [PackingEvent] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM packing ORDER BY recordedAt, rowid").map { row in
                let value = try Self.decode(PackingEvent.self, row); try value.validate(); try Self.check(value.id, row); try Self.check(value.parcelID, row, column: "parcelID")
                guard value.recordedAt == row["recordedAt"] as Int64 else { throw StoreError.corruptPayload }; return value
            }
        }
    }
}
