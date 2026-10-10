import SwiftUI
import ResaleDeskKit

struct ConditionView: View {
    let model: InventoryModel
    let item: Item
    @State private var rubricID: String
    @State private var answersByRubric: [String: [String: ConditionAnswer]] = [:]
    private var currentAnswers: [String: ConditionAnswer] { answersByRubric[rubricID] ?? [:] }
    @State private var error: String?
    @State private var savedNotice = false
    @State private var templates: [RubricTemplate] = []
    @State private var customizing = false
    @State private var loaded = false
    @FocusState private var focusedField: String?

    init(model: InventoryModel, item: Item) {
        self.model = model; self.item = item
        let starter = switch item.category {
        case "Electronics": "electronics"
        case "Books and media": "books-media"
        case "Homeware": "homeware-general"
        default: "apparel-general"
        }
        _rubricID = State(initialValue: starter)
    }

    private var activeRubric: RubricTemplate? { templates.first { $0.id == rubricID } }
    private var grade: ConditionGrade {
        guard let activeRubric else { return .unknown }
        let answers = activeRubric.questions.map {
            currentAnswers[$0.id] ?? ConditionAnswer(questionID: $0.id, value: .unknown)
        }
        return (try? activeRubric.grade(answers)) ?? .unknown
    }

    var body: some View {
        List {
            Section("Condition summary") {
                HStack {
                    Text("Grade summary")
                    Spacer()
                    Text(grade.rawValue.capitalized)
                        .bold()
                        .accessibilityIdentifier("condition.grade")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Grade summary: \(grade.rawValue)")
                Text("Grade summary updates when all required checks have answers. Missing or unknown checks leave the summary as unknown.")
                    .font(.footnote)
            }

            Section("Template") {
                Picker("Rubric template", selection: $rubricID) {
                    ForEach(templates, id: \.id) { Text($0.id).tag($0.id) }
                }
                .frame(minHeight: 48)
                .accessibilityIdentifier("condition.rubricPicker")
                .onChange(of: rubricID) { _, _ in
                    savedNotice = false
                }
                Button("Add custom check to template", systemImage: "plus") {
                    customizing = true
                }
                .frame(minHeight: 48)
                .accessibilityIdentifier("condition.addCustomCheck")
            }

            if let activeRubric {
                Section("Checks") {
                    ForEach(activeRubric.questions, id: \.id) { q in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(q.displayTitle)\(q.required ? " (required)" : " (optional)")")
                                .font(.headline)
                            ForEach(CheckValue.allCases, id: \.self) { value in
                                Button {
                                    answersByRubric[rubricID, default: [:]][q.id] = ConditionAnswer(questionID: q.id, value: value, note: currentAnswers[q.id]?.note)
                                    savedNotice = false
                                } label: {
                                    Label(value.rawValue.capitalized, systemImage: (currentAnswers[q.id]?.value ?? .unknown) == value ? "checkmark.circle.fill" : "circle")
                                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                }
                                .accessibilityLabel("\(value.rawValue) for \(q.displayTitle)")
                                .accessibilityValue((currentAnswers[q.id]?.value ?? .unknown) == value ? "Selected" : "Not selected")
                                .accessibilityIdentifier("condition.check.\(q.id).\(value.rawValue)")
                                .buttonStyle(.bordered)
                            }

                            TextField("Defect or condition note (optional)", text: Binding(
                                get: { currentAnswers[q.id]?.note ?? "" },
                                set: { newNote in
                                    answersByRubric[rubricID, default: [:]][q.id] = ConditionAnswer(
                                        questionID: q.id, value: currentAnswers[q.id]?.value ?? .unknown, note: newNote
                                    )
                                    savedNotice = false
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(minHeight: 48)
                            .accessibilityLabel("Note for \(q.displayTitle)")
                            .accessibilityIdentifier("condition.note.\(q.id)")
                            .focused($focusedField, equals: q.id)
                            .onSubmit { focusedField = nil }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Button("Save condition evaluation") {
                    guard let activeRubric else { return }
                    let answers = activeRubric.questions.map { q in
                        let existing = currentAnswers[q.id]
                        let trimmedNote = existing?.note?.trimmingCharacters(in: .whitespacesAndNewlines)
                        return ConditionAnswer(
                            questionID: q.id,
                            value: existing?.value ?? .unknown,
                            note: (trimmedNote?.isEmpty == false) ? trimmedNote : nil
                        )
                    }
                    do {
                        try model.saveCondition(item, rubric: activeRubric, answers: answers)
                        savedNotice = true
                    } catch { self.error = error.localizedDescription }
                }
                .frame(minHeight: 48)
                .accessibilityIdentifier("condition.save")

                if savedNotice {
                    Text("Condition saved locally.")
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("condition.savedNotice")
                }
                if let error {
                    Text(error).foregroundStyle(.red).accessibilityIdentifier("condition.error")
                }
            }
        }
        .navigationTitle("Condition rubric")
        .sheet(isPresented: $customizing) {
            if let activeRubric {
                CustomCheckEditor(model: model, original: activeRubric) { newRubric in
                    answersByRubric[newRubric.id] = currentAnswers
                    templates.append(newRubric)
                    rubricID = newRubric.id
                    savedNotice = false
                }
            }
        }
        .task {
            guard !loaded else { return }
            do {
                templates = try model.rubrics()
                if let existing = try model.condition(item) {
                    rubricID = existing.rubricID
                    answersByRubric[existing.rubricID] = Dictionary(uniqueKeysWithValues: existing.answers.map { ($0.questionID, $0) })
                }
                loaded = true
            } catch { self.error = error.localizedDescription }
        }
    }
}

struct CustomCheckEditor: View {
    let model: InventoryModel
    let original: RubricTemplate
    let onCreated: @MainActor @Sendable (RubricTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var checkTitle = ""
    @State private var isRequired = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("New check") {
                    TextField("Check description", text: $checkTitle)
                        .accessibilityLabel("Check description")
                        .accessibilityIdentifier("customCheck.title")
                        .frame(minHeight: 48)
                        .focused($focused)
                        .onSubmit { focused = false }
                    Toggle("Required for grade", isOn: $isRequired)
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("customCheck.required")
                }
                Section {
                    Button("Add to customized template") {
                        let trimmed = checkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let newQuestionID = "custom-\(UUID().uuidString.prefix(8).lowercased())"
                        let newQuestion = RubricQuestion(id: newQuestionID, title: trimmed, required: isRequired)
                        let newTemplateID = "\(original.id)-custom-\(UUID().uuidString.prefix(6).lowercased())"
                        var questions = original.questions
                        questions.append(newQuestion)
                        let customized = RubricTemplate(id: newTemplateID, questions: questions)
                        do {
                            try model.saveRubric(customized)
                            onCreated(customized)
                            dismiss()
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                    .frame(minHeight: 48)
                    .disabled(checkTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("customCheck.save")

                    if let error {
                        Text(error).foregroundStyle(.red).accessibilityIdentifier("customCheck.error")
                    }
                }
            }
            .navigationTitle("Add custom check")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 48, minHeight: 48)
                        .accessibilityIdentifier("customCheck.cancel")
                }
            }
        }
    }
}
