# M2 domain and persistence

`ResaleDeskKit` models are Codable, Sendable values. Validate decoded values before using them; `DeskDatabase` validates all writes and checks payload identity on reads.

- Required rubric checks must exist and be pass/fail. A missing or unknown required answer yields `unknown`. Optional answers do not affect the grade. Zero required failures gives `excellent`, one gives `good`, two or more gives `fair`. These are checklist summaries, not authenticity certification or market appraisal.
- Prices are optional integer cents, never inferred. Minimum cannot exceed a known asking price. Per-item price times cannot go backwards; equal timestamps preserve insertion order.
- One terminal outcome per item: sold, unsold, or donated. Further prices/listing edits are rejected. Sold net amounts may be negative (a recorded loss). Non-sale outcomes cannot carry net proceeds.
- A season total includes recorded sold net amounts only. Any sold amount missing in that season makes the result unknown; prices never enter sale totals. No sales is a known zero. Overflow and duplicate outcomes throw, never silently wrap or double-count.
- Parcel membership updates are atomic and must reference existing items. Membership freezes after packing history exists. Packing checks can be reversed only by appending another event.
- Item photo paths are a local relative-path manifest, not photo capture or file management. Duplicate, absolute, empty and traversal paths are rejected. Photo UI/file lifecycle arrives in M3.

GRDB 7.11.1 is pinned exactly with its resolved revision committed. Dependency download is a build-time operation; app/domain runtime network APIs remain forbidden. The gate permits only this exact manifest line and rejects alternate pins and unrelated packages.

`DeskDatabase(path:)` opens a local SQLite queue with foreign keys enabled. Migration `v1` creates the schema; `v2-ledger-guards` adds UPDATE/DELETE rejection triggers for price, outcome and packing history and query indexes. Each write is a GRDB transaction. No public update/delete event API exists. Rubrics referenced by condition checks cannot change in-place; create another rubric identity instead.

## Fixture and verification

`python3 scripts/make_v1_fixture.py` generates the committed `Packages/ResaleDeskStore/Tests/ResaleDeskStoreTests/Fixtures/v1.sqlite`. It deliberately lacks v2 guards and carries fixed item/price/unknown-sale records. The test copies it, migrates, checks records, adds records, closes/reopens, and proves append-only guards survive.

Container verification uses `swift:6.2-noble` and `libsqlite3-dev`, with a read-only source mount and builds in the container, leaving no root-owned worktree artifacts:

- ResaleDeskKit: 8 tests passed with warnings-as-errors. LLVM coverage of `Models.swift`: 95/95 regions, 44/44 functions, 96/96 lines (100%). This covers hand-written domain logic, not synthesized Codable internals or Apple UI.
- ResaleDeskStore: 6 tests passed with warnings-as-errors, including migration/reopen, round trips, FK rollback, terminal-state rejection and direct SQL UPDATE/DELETE rejection.
- Static contract and native-only/zero-network gates passed; gate tests cover 18 rejected fixtures and one accepted exact dependency pin.

Linux package/SQLite tests are not an iOS build, simulator run, archive, or distribution. The existing pinned Apple CI lane must pass before merge; it measures the built bundle identifier and `UIDeviceFamily == [1]`. No UI feature is claimed by this milestone.
