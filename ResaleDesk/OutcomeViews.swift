import SwiftUI
import ResaleDeskKit

struct OutcomeListView: View {
    let model: InventoryModel
    @State private var outcomes: [OutcomeEvent] = []
    @State private var items: [Item] = []
    @State private var season = Calendar.current.component(.year, from: Date())
    @State private var total: MoneyTotal = .unknown
    @State private var recording = false
    @State private var error: String?

    var body: some View {
        List {
            Section("Season \(String(season))") {
                Button("Record outcome", systemImage: "checklist") { recording = true }
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("outcome.record")
                switch total {
                case .known(let cents):
                    Text("Known net proceeds: \(ListingCopy.price(cents)) (your currency)")
                        .accessibilityIdentifier("outcome.total")
                case .unknown:
                    Text("Known net proceeds: Unknown. A sold item without a recorded amount keeps the season total unknown.")
                        .accessibilityIdentifier("outcome.total")
                }
                Text("Totals come only from recorded sold outcomes. Donations and unsold items never add an amount.")
                    .font(.footnote)
            }
            Section("Ledger (append-only)") {
                if outcomes.isEmpty { Text("No outcomes recorded yet.") }
                ForEach(outcomes.reversed(), id: \.id) { outcome in
                    let title = items.first { $0.id == outcome.itemID }?.title ?? "Removed item"
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(title): \(outcome.kind.rawValue.capitalized)").font(.headline)
                        if let netCents = outcome.netCents {
                            Text("Net: \(ListingCopy.price(netCents)) (your currency)").font(.caption)
                        } else if outcome.kind == .sold {
                            Text("Net: Unknown").font(.caption)
                        }
                        Text("Season \(outcome.season)").font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .accessibilityIdentifier("outcome.row.\(outcome.id)")
                }
            }
        }
        .navigationTitle("Outcomes")
        .sheet(isPresented: $recording) {
            OutcomeComposer(model: model) { load() }
        }
        .task { load() }
        .alert("Outcome error", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func load() {
        do {
            outcomes = try model.outcomes()
            items = model.items
            total = try storeTotal()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func storeTotal() throws -> MoneyTotal {
        // ponytail: read through the same store path the app uses for items; upgrade to a model-level total helper if M6 export needs it.
        try model.total(season: String(season))
    }
}

struct OutcomeComposer: View {
    let model: InventoryModel
    let onRecord: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var itemID = ""
    @State private var kind: OutcomeKind = .sold
    @State private var net = ""
    @State private var season = String(Calendar.current.component(.year, from: Date()))
    @State private var error: String?

    private var openItems: [Item] {
        let closed = Set((try? model.outcomes().map(\.itemID)) ?? [])
        return model.items.filter { !closed.contains($0.id) }
    }
    private var wantsNet: Bool { kind == .sold }
    private var validNet: Bool { net.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (try? ListingCopy.cents(net)) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    if openItems.isEmpty {
                        Text("Every item already has a terminal outcome.")
                    } else {
                        Picker("Item", selection: $itemID) {
                            Text("Choose an item").tag("")
                            ForEach(openItems, id: \.id) { item in
                                Text(item.title).tag(item.id)
                            }
                        }
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("outcome.item")
                    }
                }
                Section("Outcome") {
                    Picker("Result", selection: $kind) {
                        ForEach([OutcomeKind.sold, .returned, .donated, .discarded], id: \.self) { kind in
                            Text(kind.rawValue.capitalized).tag(kind)
                        }
                    }
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("outcome.kind")
                    if wantsNet {
                        TextField("Net proceeds (blank = unknown)", text: $net).keyboardType(.decimalPad)
                            .accessibilityLabel("Net proceeds")
                            .accessibilityIdentifier("outcome.net")
                        Text("Blank keeps the season total unknown. Enter the net amount you received after fees and shipping, with up to two decimals.")
                            .font(.footnote)
                    } else {
                        Text("This outcome records no money. Net proceeds apply only to sales.")
                            .font(.footnote)
                    }
                    TextField("Season (for example 2026)", text: $season)
                        .accessibilityLabel("Season")
                        .accessibilityIdentifier("outcome.season")
                        .frame(minHeight: 48)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("outcome.error") }
                }
            }
            .navigationTitle("Record outcome")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 48, minHeight: 48)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") { record() }
                        .disabled(itemID.isEmpty || !validNet || season.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .frame(minWidth: 48, minHeight: 48)
                        .accessibilityIdentifier("outcome.save")
                }
            }
        }
    }

    private func record() {
        do {
            try model.recordOutcome(itemID: itemID, kind: kind, netCents: wantsNet ? ListingCopy.cents(net) : nil,
                season: season.trimmingCharacters(in: .whitespacesAndNewlines))
            onRecord()
            dismiss()
        } catch {
            self.error = "Save failed. Use a nonnegative net amount with at most two decimals. \(error.localizedDescription)"
        }
    }
}
