# Resale Desk

**Pitch:** Offline iPhone resale-preparation workspace for declutterers: grade item condition against your own rubric, stage honest listing copy and prices, run a packing checklist per parcel, and keep a portable sale-outcome ledger — no marketplace accounts, no cloud.

Resale Desk is the desk you work at *before* a sale: the condition evidence, the listing draft, the box checklist, and the honest record of what happened to each item. It never talks to a marketplace. You copy your finished listing text into whatever app or website you sell on, and you type in the tracking number the carrier gave you. The app keeps the private paperwork.

## Motivation

Resale chart leaders (Vinted, Depop, eBay-class apps) bundle the marketplace, chat, payments, and shipping-label flow into one account-bound product. The actual per-item *preparation* work — grading condition honestly, photographing defects, writing listing copy that survives a dispute, packing so nothing arrives broken, remembering what actually sold for how much — happens in notes apps and photo rolls, or not at all. Resale Desk does just that preparation job, fully on-device, and exports everything.

## Target users

- People decluttering wardrobes, collections, or gear who sell on one or more marketplaces and want one private workspace across all of them.
- Casual sellers who hate that their condition notes, prices, and sale history live inside a marketplace account they cannot export.
- Anyone who wants receipts-for-your-side evidence: what the item looked like when it left, what was promised, what shipped.

## Concrete use cases

1. **Wardrobe clear-out.** Batch 30 sweaters through a "Apparel - Fall" rubric template (pilling, stains, zips, holes). Each answer is pass/fail/unknown with a note; the suggested grade only appears when every required question has an answer — unknowns stay unknown, never silently downgraded or upgraded.
2. **Listing staging.** Draft title + description per item from your own phrasing templates, keep an asking/minimum price pair, then copy the finished text to the clipboard or export it as a text file to paste into any marketplace.
3. **Parcel day.** Bundle items into a parcel, walk a packing checklist (protect, weigh, label, hand-off), record the carrier and tracking number as plain user-typed text, and log the shipped event.
4. **Honest books.** Append-only outcome ledger (listed, repriced, sold-net, returned-to-inventory, donated, discarded). Season totals derive only from recorded sold-net amounts; items with no recorded amount show as unknown, never as zero.

## How to use (intended workflow)

1. Create an item: category, brand, size/measurements, acquisition cost (optional).
2. Pick a condition rubric template (built-in starters or your own), answer each check, photograph defects into the item's local photo set.
3. Stage the listing: title, description, asking and minimum price; copy to clipboard when done.
4. On ship day, assemble a parcel, complete the packing checklist, type in carrier + tracking number.
5. Log the outcome when it happens; export CSV or a versioned JSON backup whenever you like.

## MVP feature list

- Item inventory with per-item local photo sets (user-picked/imported photos stored in the app sandbox).
- User-editable condition rubric templates; grade derivation is unknown-safe (missing required answers yield `unknown`, never a guessed grade).
- Listing drafts with price history (append-only) and clipboard/file export of finished copy.
- Parcel worklist with packing checklists and user-typed carrier/tracking text (never network-verified).
- Append-only outcome ledger with unknown-safe season/total derivation.
- Versioned JSON backup with previewed restore; CSV export of items, listings, parcels, outcomes.
- Full VoiceOver labeling, Dynamic Type, large one-thumb controls on the capture and packing screens.

## Non-goals

- No marketplace or carrier API integration of any kind; the app has zero network access. No account, no sync, no ads, no analytics.
- No cross-platform frameworks: no Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity. Native Swift only.
- No automatic price suggestion from market data (no network), no barcode scanning, no shipping-label purchase, no payments.
- No authenticity appraisal or medical/safety claims about items.
- No Android, and native iPad support is disabled (explicit user opt-in only; iPhone compatibility mode on iPad is a different thing).
- No cloud photo backup.

## iPhone Duo dual-screen design target (and today's build shape)

The core workspace wants two surfaces: item photos + condition evidence on one screen while listing copy, price controls, and the packing checklist live on the other as a persistent control surface — plus a folded one-handed quick-capture mode. Because native fold APIs are not yet available, Resale Desk ships **today as a standard single-screen native Swift iPhone app with iPad support disabled**; nothing depends on unavailable dual-screen SDK APIs. All dual-screen layout decisions funnel through a single seam named `ListingWorkspaceLayout`, documented in issue #5, so a future Duo build swaps the seam's implementation, not the product.

## Privacy, permissions, and data storage

- Zero network access (enforced as a CI contract, not a promise). No accounts, no trackers, no third-party SDKs.
- Everything lives in a local SQLite database plus photo files inside the app sandbox.
- Permissions: photo library access only when you explicitly pick or import photos (`NSPhotoLibraryUseDescription`-style purpose text); camera when photographing defects. Notifications optional, only for user-created packing reminders if enabled.
- Export/backup is user-initiated: versioned JSON backup (with restore preview) and CSV exports you own.
- Defect photos can contain faces/addresses; the app never uploads them and the export flow says so plainly.

## Bundle identifier and App Store Connect

- Bundle identifier: `com.infinityball.resaledesk` — the `com.infinityball.` prefix is mandatory fleet policy and must match `PRODUCT_BUNDLE_IDENTIFIER`, Info.plist, and all signing/provisioning configuration in every future target.
- App Store Connect registration: `CREATED com.infinityball.resaledesk` (registered via the ASC API on 2026-10-06).
- GitHub Actions repository secrets configured (names only): ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID.

## Platform and toolchain contract

- Native Swift (SwiftUI/UIKit) iPhone-only iOS app, iOS 26 SDK or newer (pinned Xcode 26.0.1 / 17A400 / iOS SDK 26.0 / Swift 6 in `toolchain.json`), built and CI-tested with an App Store/TestFlight path.
- `TARGETED_DEVICE_FAMILY = 1` in every app-target configuration; native iPad support is disabled; the built app's `UIDeviceFamily` must verify as `[1]` on an Apple runner.
- Prohibited frameworks in scaffold, docs, CI, issues, and executor prompts: Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity.

## Current status

M3 condition capture workflow: inventory list and item creation, category-appropriate rubric starters (apparel, electronics, books, homeware) plus custom check additions, live unknown-safe grade summary, pass/fail/unknown answers with optional defect notes, and camera-only sandbox photo capture with metadata-free JPEG encoding. GRDB SQLite persistence backs all entities with v2 ledger guards. Linux package tests and static zero-network, native-only, and contract gates pass. The pinned Apple CI checks app compilation and built `UIDeviceFamily == [1]`; camera capture, VoiceOver, and large Dynamic Type still need device review. Icon artwork, release workflow, signed archive, and TestFlight build remain issue #7 work. See [bootstrap evidence](docs/bootstrap-evidence.md) and [domain store](docs/domain-store.md).

## Milestones

1. M1 — Skeleton + CI contract gates (issue #1)
2. M2 — Domain + store layer (issue #2)
3. M3 — Condition capture workflow (issue #3)
4. M4 — Listing staging + export (issue #4)
5. M5 — Parcels, outcome ledger, `ListingWorkspaceLayout` seam (issue #5)
6. M6 — Backup/export/privacy (issue #6)
7. M7 — Icon, listing copy review, release pipeline (issue #7)

## Development quickstart

Open `ResaleDesk.xcodeproj` in Xcode 26.0.1 (17A400) and build the `ResaleDesk` scheme for iOS Simulator. Run `swift test --package-path Packages/ResaleDeskKit` and `swift test --package-path Packages/ResaleDeskStore`; run `bash scripts/check_zero_network.sh`, `bash scripts/check_native_only.sh`, and `swift scripts/check_contract.swift` for static gates. CI runs both packages on Linux and on a pinned macOS runner, where it also builds the iPhone app and inspects the built plist. The store is GRDB-backed; photo imports are user-initiated and remain in Application Support.

## License

MIT — see LICENSE.
