import SwiftUI
import ResaleDeskKit

struct ParcelListView: View {
    let model: InventoryModel
    @State private var parcels: [Parcel] = []
    @State private var outcomes: [OutcomeEvent] = []
    @State private var packing: [PackingEvent] = []
    @State private var newParcel = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Button("Create parcel", systemImage: "shippingbox.fill") { newParcel = true }
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("parcel.create")
            }
            if parcels.isEmpty {
                Section {
                    Text("No parcels yet. Group items ready to ship and track their packing steps offline.")
                }
            } else {
                Section("Parcels") {
                    ForEach(parcels, id: \.id) { parcel in
                        NavigationLink {
                            ParcelDetailView(model: model, parcel: parcel)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Parcel with \(parcel.itemIDs.count) item(s)").font(.headline)
                                if !parcel.carrier.isEmpty {
                                    Text("Carrier: \(parcel.carrier)").font(.subheadline).foregroundStyle(.secondary)
                                }
                                if !parcel.tracking.isEmpty {
                                    Text("Tracking: \(parcel.tracking)").font(.caption).foregroundStyle(.secondary)
                                }
                                let completed = PackingChecklist.completed(packing, parcelID: parcel.id).count
                                Text("Checklist: \(completed) of \(PackingChecklist.keys.count) done")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityIdentifier("parcel.row.\(parcel.id)")
                    }
                }
            }
        }
        .navigationTitle("Parcels")
        .sheet(isPresented: $newParcel) {
            ParcelComposer(model: model) {
                load()
            }
        }
        .task { load() }
        .alert("Parcel error", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func load() {
        do {
            parcels = try model.parcels()
            outcomes = try model.outcomes()
            packing = try model.packingEvents()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ParcelComposer: View {
    let model: InventoryModel
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItemIDs: Set<String> = []
    @State private var carrier = ""
    @State private var tracking = ""
    @State private var error: String?

    // Candidate items: not yet terminal in outcome ledger, and not already in another parcel.
    private var eligibleItems: [Item] {
        let soldOrClosed = Set((try? model.outcomes().map(\.itemID)) ?? [])
        let assigned = Set((try? model.parcels().flatMap(\.itemIDs)) ?? [])
        return model.items.filter { !soldOrClosed.contains($0.id) && !assigned.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Items to include") {
                    if eligibleItems.isEmpty {
                        Text("No items available to pack. Items must not be closed or already in another parcel.")
                    }
                    ForEach(eligibleItems, id: \.id) { item in
                        Toggle(isOn: Binding(
                            get: { selectedItemIDs.contains(item.id) },
                            set: { if $0 { selectedItemIDs.insert(item.id) } else { selectedItemIDs.remove(item.id) } }
                        )) {
                            VStack(alignment: .leading) {
                                Text(item.title).font(.headline)
                                Text(item.category ?? "Uncategorized").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("parcel.compose.toggle.\(item.id)")
                    }
                }
                Section("Carrier info (optional, offline)") {
                    TextField("Carrier name (e.g. USPS, UPS)", text: $carrier)
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("parcel.compose.carrier")
                    TextField("Tracking number", text: $tracking)
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("parcel.compose.tracking")
                    Text("Stored locally on this device only. Never sent to any carrier or shipping API.")
                        .font(.footnote)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("New parcel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 48, minHeight: 48)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(selectedItemIDs.isEmpty)
                    .frame(minWidth: 48, minHeight: 48)
                    .accessibilityIdentifier("parcel.compose.save")
                }
            }
        }
    }

    private func save() {
        let parcel = Parcel(
            id: UUID().uuidString,
            itemIDs: Array(selectedItemIDs),
            carrier: carrier.trimmingCharacters(in: .whitespacesAndNewlines),
            tracking: tracking.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            try model.saveParcel(parcel)
            onSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ParcelDetailView: View {
    let model: InventoryModel
    let parcel: Parcel
    @State private var carrier: String
    @State private var tracking: String
    @State private var packing: [PackingEvent] = []
    @State private var notice = ""
    @State private var error: String?

    init(model: InventoryModel, parcel: Parcel) {
        self.model = model
        self.parcel = parcel
        _carrier = State(initialValue: parcel.carrier)
        _tracking = State(initialValue: parcel.tracking)
    }

    private var items: [Item] {
        model.items.filter { parcel.itemIDs.contains($0.id) }
    }

    private var completedKeys: Set<String> {
        PackingChecklist.completed(packing, parcelID: parcel.id)
    }

    var body: some View {
        Form {
            Section("Parcel items (\(items.count))") {
                ForEach(items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.headline)
                        Text(item.category ?? "Uncategorized").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Packing checklist") {
                Text("Step through verification before sealing the box. Stored append-only.")
                    .font(.footnote)
                checklistRow(key: "condition-checked", label: "Final condition matches record")
                checklistRow(key: "contents-checked", label: "All item contents present")
                checklistRow(key: "protected", label: "Protective packaging added")
                checklistRow(key: "sealed", label: "Box securely taped and sealed")
            }

            Section("Carrier & tracking (offline)") {
                TextField("Carrier", text: $carrier)
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("parcel.carrier")
                TextField("Tracking number", text: $tracking)
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("parcel.tracking")
                Button("Save carrier details") { saveCarrier() }
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("parcel.saveCarrier")
                Text("Offline record only. Never shared or validated with external services.")
                    .font(.footnote)
            }

            if !notice.isEmpty {
                Section { Text(notice).foregroundStyle(.green).accessibilityIdentifier("parcel.notice") }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("parcel.error") }
            }
        }
        .navigationTitle("Parcel packing")
        .task { load() }
    }

    @ViewBuilder
    private func checklistRow(key: String, label: String) -> some View {
        let isDone = completedKeys.contains(key)
        Button {
            toggleStep(key: key, currentlyDone: isDone)
        } label: {
            HStack {
                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                    .foregroundColor(isDone ? .accentColor : .secondary)
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .frame(minHeight: 48)
        .accessibilityIdentifier("parcel.step.\(key)")
        .accessibilityValue(isDone ? "Done" : "Not done")
    }

    private func toggleStep(key: String, currentlyDone: Bool) {
        do {
            try model.recordPacking(parcelID: parcel.id, key: key, completed: !currentlyDone)
            packing = try model.packingEvents()
            notice = "Checklist updated."
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveCarrier() {
        let updated = Parcel(
            id: parcel.id,
            itemIDs: parcel.itemIDs,
            carrier: carrier.trimmingCharacters(in: .whitespacesAndNewlines),
            tracking: tracking.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            try model.saveParcel(updated)
            notice = "Carrier details saved locally."
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func load() {
        do {
            packing = try model.packingEvents()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
