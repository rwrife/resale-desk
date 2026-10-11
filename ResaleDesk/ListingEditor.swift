import SwiftUI
import UIKit
import ResaleDeskKit

struct ListingEditor: View {
    let model: InventoryModel
    let item: Item
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var draftID = UUID().uuidString
    @State private var title = ""
    @State private var description = ""
    @State private var asking = ""
    @State private var minimum = ""
    @State private var condition: ItemCondition?
    @State private var rubric: RubricTemplate?
    @State private var history: [PriceEvent] = []
    @State private var loaded = false
    @State private var error: String?
    @State private var notice = ""
    @AppStorage("listing.titleTemplate") private var titleTemplate = "{title}"
    @AppStorage("listing.descriptionTemplate") private var descriptionTemplate = "{title}\nCategory: {category}\nCondition summary: {grade}\n{checks}\nNotes:\n{notes}"
    @FocusState private var focused: Bool

    private var validPrice: Bool {
        do { _ = try ListingCopy.cents(asking); return true } catch { return false }
    }
    private var exportText: String {
        ListingCopy.shareExport(title: title, description: description, askingCents: try? ListingCopy.cents(asking))
    }
    private var evidence: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Item evidence").font(.headline)
            Text(item.title).bold()
            Text(item.category ?? "Uncategorized")
            Text("\(item.photoPaths.count) local photos (not exported)").font(.footnote)
            Text(ListingCopy.composeDescription(item: item, condition: condition, rubric: rubric,
                template: "Summary: {grade}\n{checks}\nNotes:\n{notes}"))
                .accessibilityIdentifier("listing.evidence")
            Text("Your checks, not certification.").font(.footnote)
        }.frame(maxWidth: .infinity, alignment: .topLeading)
    }
    private var fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Draft fields").font(.headline)
            TextField("Draft title", text: $title, axis: .vertical)
                .accessibilityLabel("Draft title").accessibilityIdentifier("listing.title")
            TextField("Draft description", text: $description, axis: .vertical)
                .accessibilityLabel("Draft description").accessibilityIdentifier("listing.description")
        }.textFieldStyle(.roundedBorder).focused($focused)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Evidence & draft") {
                    // ponytail: two columns on standard iPhone text; stack for accessibility.
                    // Future dual-display presentation belongs only in ListingWorkspaceLayout (M5).
                    if textSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 16) { evidence; fields } }
                    else { HStack(alignment: .top, spacing: 16) { evidence; fields } }
                }
                Section("Prices in your currency") {
                    TextField("Asking price", text: $asking).keyboardType(.decimalPad)
                        .accessibilityLabel("Asking price").accessibilityIdentifier("listing.asking")
                    TextField("Private minimum price", text: $minimum).keyboardType(.decimalPad)
                        .accessibilityLabel("Private minimum price").accessibilityIdentifier("listing.minimum")
                    Text("Blank means unknown. Up to two decimal places. The private minimum is excluded from listing copy.")
                        .font(.footnote)
                }.focused($focused)
                Section {
                    Button("Save draft & prices") { save() }
                        .accessibilityIdentifier("listing.save").disabled(!loaded)
                    Text(notice).accessibilityIdentifier("listing.notice")
                    if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("listing.error") }
                }
                Section("Personal templates (saved on this iPhone)") {
                    Text("Tokens: {title}, {category}, {grade}, {checks}, {notes}. Applying replaces draft text, not saved history.").font(.footnote)
                    TextField("Title template", text: $titleTemplate, axis: .vertical)
                        .accessibilityLabel("Title template").accessibilityIdentifier("listing.titleTemplate")
                    TextField("Description template", text: $descriptionTemplate, axis: .vertical)
                        .accessibilityLabel("Description template").accessibilityIdentifier("listing.descriptionTemplate")
                    Button("Apply my template") {
                        title = ListingCopy.composeTitle(item: item, template: titleTemplate)
                        description = ListingCopy.composeDescription(item: item, condition: condition, rubric: rubric, template: descriptionTemplate)
                        notice = "Template applied. Save to keep the draft."
                    }.accessibilityIdentifier("listing.applyTemplate").disabled(!loaded)
                }.focused($focused)
                Section("Append-only price history") {
                    if history.isEmpty { Text("No saved price snapshots.") }
                    ForEach(history.reversed(), id: \.id) { event in
                        VStack(alignment: .leading) {
                            Text("Asking: \(event.askingCents.map { ListingCopy.price($0) } ?? "Unknown")")
                            Text("Private minimum: \(event.minimumCents.map { ListingCopy.price($0) } ?? "Unknown")")
                            Text(Date(timeIntervalSince1970: TimeInterval(event.recordedAt) / 1000), format: .dateTime)
                                .font(.caption)
                        }
                    }
                }
                Section("Export plain text") {
                    Text("Review your copy and defect notes before exporting. Clipboard and share recipients are outside this app's private storage. No photos or private minimum are included.").font(.footnote)
                    Button("Copy listing to clipboard") {
                        UIPasteboard.general.setItems([["public.utf8-plain-text": exportText]], options: [.localOnly: true])
                        notice = "Listing copy copied to this device's clipboard."
                    }.accessibilityIdentifier("listing.copy").disabled(!loaded || !validPrice)
                    ShareLink(item: exportText) { Text("Share listing copy") }
                        .accessibilityIdentifier("listing.share").disabled(!loaded || !validPrice)
                }
            }
            .navigationTitle("Listing draft")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
            }
            .task { load() }
        }
    }
    private func load() {
        guard !loaded else { return }
        do {
            condition = try model.condition(item)
            if let condition { rubric = try model.rubric(for: condition) }
            history = try model.priceHistory(for: item)
            if let draft = try model.draft(for: item) {
                draftID = draft.id; title = draft.title; description = draft.description
            } else {
                title = item.title
            }
            asking = ListingCopy.price(history.last?.askingCents)
            minimum = ListingCopy.price(history.last?.minimumCents)
            loaded = true
        } catch { self.error = "Cannot load listing: \(error.localizedDescription)" }
    }
    private func save() {
        focused = false
        do {
            let draft = ListingDraft(id: draftID, itemID: item.id, title: title, description: description)
            try model.saveListing(draft, askingCents: ListingCopy.cents(asking), minimumCents: ListingCopy.cents(minimum))
            history = try model.priceHistory(for: item)
            notice = "Draft and prices saved locally."
            error = nil
        } catch { self.error = "Save failed. Use nonnegative prices with at most two decimals and minimum no higher than asking. \(error.localizedDescription)" }
    }
}
