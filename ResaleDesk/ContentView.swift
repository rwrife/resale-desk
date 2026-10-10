import SwiftUI
import ResaleDeskKit

struct ContentView: View {
    @State private var model = InventoryModel()
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Add item", systemImage: "plus") { adding = true }
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("inventory.add")
                    if model.items.isEmpty {
                        Text("Your inventory is empty. Add an item to record its condition and photos locally.")
                    }
                    ForEach(model.items, id: \.id) { item in
                        NavigationLink {
                            ItemDetailView(model: model, itemID: item.id)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.title).font(.headline)
                                Text(item.category ?? "Uncategorized").foregroundStyle(.secondary)
                                Text("\(item.photoPaths.count) local photos").font(.footnote)
                            }.padding(.vertical, 8)
                        }
                        .accessibilityIdentifier("inventory.item.\(item.id)")
                    }
                }
                Section {
                    Text("Offline preparation only. Condition grades summarize your checks; they are not authenticity certification.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Resale Desk")
            .sheet(isPresented: $adding) { ItemEditor(model: model, item: nil) }
            .alert("Local storage error", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
        }
    }
}

struct ItemEditor: View {
    let model: InventoryModel
    let itemID: String?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var category: String
    @State private var error: String?
    @FocusState private var focused: Bool

    init(model: InventoryModel, item: Item?) {
        self.model = model
        self.itemID = item?.id
        _title = State(initialValue: item?.title ?? "")
        _category = State(initialValue: item?.category ?? "Apparel")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item title", text: $title, axis: .vertical)
                    .accessibilityLabel("Item title")
                    .accessibilityIdentifier("item.title")
                    .frame(minHeight: 48)
                    .focused($focused).onSubmit { focused = false }
                Picker("Category", selection: $category) {
                    ForEach(["Apparel", "Electronics", "Books and media", "Homeware", "Other"], id: \.self) { Text($0).tag($0) }
                }
                .frame(minHeight: 48)
                .accessibilityIdentifier("item.category")
                Button("Save item") {
                    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    do {
                        if let itemID {
                            try model.updateMetadata(itemID: itemID, title: cleanTitle, category: category)
                        } else {
                            try model.save(Item(id: UUID().uuidString, title: cleanTitle, category: category))
                        }
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
                .frame(minHeight: 48).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("item.save")
                if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("item.error") }
            }
            .navigationTitle(itemID == nil ? "New item" : "Edit item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 48, minHeight: 48)
                        .accessibilityIdentifier("item.cancel")
                }
            }
        }
    }
}
