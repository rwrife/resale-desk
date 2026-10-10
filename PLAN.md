# Resale Desk — delivery plan

## Scope and architecture

A single standard native Swift iPhone app for private resale preparation. No seller-account connector or carrier API. The product is deliberately narrower than a marketplace: document condition, stage listing copy, pack a parcel, and record the outcome. Everything is editable and exportable by its owner.

- `ResaleDeskKit`: pure-Swift models (`Item`, `RubricTemplate`, `ConditionAnswer`, `ListingDraft`, `PriceEvent`, `Parcel`, `PackingEvent`, `OutcomeEvent`) and deterministic derivation. Missing answers and prices propagate `unknown`; no inferred sale value or grade. Append-only events preserve price and outcome history; transitions validate impossible sequences.
- `ResaleDeskStore`: GRDB-backed SQLite migrations, photo-file manifest, transaction boundaries. Exact restore preview separates merge/replace with rollback on failure; export schema versioned.
- `ResaleDeskApp`: SwiftUI screens for one-handed inventory, condition, draft, parcel worklist, outcome capture, and exports. A single `ListingWorkspaceLayout` seam chooses folded single-pane vs future dual-screen workspace without relying on unreleased APIs.
- UI and domain must not make network requests; CI runs a zero-network allowlist check across app dependencies and entitlements.

## Technology choices

Native Swift 6, SwiftUI/UIKit, Swift Package Manager and Xcode 26.0.1 (17A400), iOS 26.0+ SDK. GRDB is the local SQLite bridge; Foundation JSON and CSV codecs for exports; PhotosUI or UIKit photo picker and AVFoundation camera only on explicit user action. No remote AI. No ads, no accounts, no cloud. The bundle ID is `com.infinityball.resaledesk` in `PRODUCT_BUNDLE_IDENTIFIER`, Info.plist, and signing configurations. `TARGETED_DEVICE_FAMILY = 1` in every app-target build configuration, generator, and release lane; Apple CI verifies built `UIDeviceFamily == [1]`. Native iPad support is disabled; iPad compatibility mode is not native support.

No Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity or other cross-platform/hybrid frameworks. Android and iPad are out of scope. No unavailable foldable APIs; iPhone Duo is a future layout migration through `ListingWorkspaceLayout` only.

## Milestones and dependencies

1. **Skeleton + CI** — create Xcode project, Swift packages, minimal app route, iPhone-only settings, zero-network static checks; Apple CI asserts exact Xcode/SDK and built UIDeviceFamily. No code exists at scaffold time.
2. **Domain + persistence** — condition rubric engine, unknown-safe grade, listing/price/parcel/outcome events, SQLite migrations, fixture tests. Implemented in M2; verification and API details: [domain-store.md](docs/domain-store.md). Depends on 1.
3. **Condition workflow** — items, photos, editable rubric, required-answer preview, VoiceOver and Dynamic Type. Implemented in M3; inventory listing, item editor, rubric evaluation with pass/fail/unknown checks and notes, custom check additions, camera-only sandbox photo capture with JPEG metadata stripping, zero network, VoiceOver labels, and 48pt+ one-thumb controls. Device VoiceOver/Dynamic Type review remains pending. Depends on 2.
4. **Listing staging** — title/description and asking/minimum price editing; copy and file exports of draft; no marketplace publishing. Depends on 3.
5. **Parcel + outcomes** — packing checklist, typed carrier/tracking, event-derived sales totals, `ListingWorkspaceLayout` seam and single-screen iPhone QA. Depends on 4.
6. **Privacy/export/backup** — CSV plus versioned JSON backup, previewed restore, permission prompts, zero-network and redaction verification. Depends on 5.
7. **Release** — review `AppStore/description.txt` against the implemented app; generate and inspect real `AppStore/icon.png` using the specified `hermes-image-gen` model from repo + description, wire into Xcode asset catalog; port `.github/workflows/release.yml` from rwrife/cook-console. Depends on 1–6 and the actual art/model availability.

## Testing strategy

- Pure-Swift deterministic rubric and ledger tests for pass/fail/unknown states, grade derivation, invalid transitions, empty prices, and reproducible export.
- GRDB migration and round-trip tests with fixture databases, interrupted restore rollback, photo-manifest orphan detection.
- XCUITest of inventory → condition → listing copy → parcel → sale, Dynamic Type and VoiceOver checks on the pinned iOS 26 simulator.
- Apple CI measures actual `xcodebuild -version`, SDK version, project and built `UIDeviceFamily`. Linux syntax/contract checks are not a substitute for an Apple archive.
- Negative zero-network gate checks app entitlements/dependencies for outbound network APIs. No shipment-tracking or marketplace API smoke test exists because they are explicitly out of scope.

## Privacy, accessibility, and limitations

On-device SQLite and photos. Photo/camera access requested only by user action; optional local packing reminder notification. No permissions otherwise. Backup and export are user-triggered. Defect photos, tracking strings, and listing drafts are private and are never transmitted by the app. Accessibility includes VoiceOver labels, Dynamic Type, contrast, reversible large controls, and no color-only state. The app does not appraise authenticity, set market prices, guarantee packing adequacy, sell, ship, or handle payments.

## Packaging and distribution

`com.infinityball.resaledesk` is already registered in App Store Connect; the repo has secret names ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID configured. The exact bundle ID must remain in every target, `PRODUCT_BUNDLE_IDENTIFIER`, Info.plist, and signing configuration. No signing result exists yet.

Release issue #7 must implement `.github/workflows/release.yml` by **porting** the green rwrife/cook-console template (also present in rise-log, split-slip, catch-tally): `v*` tag push or manual dispatch → macos-26 job → enforce iOS 26+ SDK and pinned Xcode 26.0.1/17A400 → materialize ASC API key mode 0600 (never log values) → signed IPA archive/export → TestFlight upload via App Store Connect API using all four secret names → poll processing → GitHub release. Require actual workflow-run URL, processed build ID, and archive evidence before claiming a release. Do not invent a signing flow. `AppStore/description.txt` is scaffolded copy, not a store listing; `AppStore/icon.png` and a built asset catalog are still missing.

## Risks / explicit non-goals

- Photo sets can be large: size limits and export warning; no automatic cloud backup.
- Parcel hand-off and carrier tracking are user-entered claims, not carrier verification.
- Local totals represent known logged sales only; missing proceeds remain unknown, never zero.
- No Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity; no Android or native iPad implementation; no marketplace account, purchase, payment, shipment tracking, or automatic pricing; no medical, safety, or authenticity certification.
