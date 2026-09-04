import SwiftData
import SwiftUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let metric: MetricDefinition
    let entry: MetricEntry?

    @State private var timestamp: Date
    @State private var amount: Double
    @State private var textValue: String
    @State private var note: String
    @State private var selectedChoices: Set<String>
    @State private var selectedMedicationID: UUID?
    @State private var doseUnit: String

    init(metric: MetricDefinition, entry: MetricEntry? = nil, suggestedDate: Date = .now) {
        self.metric = metric
        self.entry = entry
        _timestamp = State(initialValue: entry?.timestamp ?? suggestedDate)
        let matchedMedication = metric.medications.first { $0.name == entry?.textValue }
        let initialMedication = matchedMedication ?? metric.medications.first
        _amount = State(initialValue: entry?.numericValue ?? initialMedication?.defaultDose ?? metric.defaultValue)
        _textValue = State(initialValue: entry?.textValue ?? "")
        _note = State(initialValue: entry?.note ?? "")
        _selectedChoices = State(initialValue: Set(entry?.selectedChoices ?? []))
        _selectedMedicationID = State(initialValue: initialMedication?.id)
        _doseUnit = State(initialValue: entry?.valueUnit ?? initialMedication?.unit ?? "mg")
    }

    private var canSave: Bool {
        switch metric.kind {
        case .choice: !textValue.isEmpty
        case .multiChoice: !selectedChoices.isEmpty
        case .note: !textValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .medication: selectedMedicationID != nil
        default: true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                whenSection
                valueSection

                if metric.kind != .note {
                    Section("Optional note") {
                        TextField("Anything else worth remembering?", text: $note, axis: .vertical)
                            .lineLimit(2...6)
                    }
                }
            }
            .navigationTitle(entry == nil ? "Log \(metric.name)" : "Edit \(metric.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(entry == nil ? "Add" : "Save") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var whenSection: some View {
        Section {
            DatePicker("Date and time", selection: $timestamp, in: ...Date.now)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    dateShortcut("Now", date: .now)
                    dateShortcut("1 hour ago", date: Calendar.current.date(byAdding: .hour, value: -1, to: .now) ?? .now)
                    dateShortcut("Earlier today", date: earlierToday)
                    dateShortcut("Yesterday", date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
        } header: {
            Text("When did it happen?")
        } footer: {
            Text("Log something from earlier today or any previous day. You can change this later.")
        }
    }

    @ViewBuilder
    private var valueSection: some View {
        switch metric.kind {
        case .scale:
            Section(metric.prompt) {
                VStack(spacing: 12) {
                    Text(amount.formatted(.number.precision(.fractionLength(0...2))))
                        .font(.largeTitle.monospacedDigit().bold())
                        .foregroundStyle(Color(hex: metric.colorHex))
                    Slider(value: $amount, in: metric.minimumValue...metric.maximumValue, step: max(0.01, metric.stepValue))
                        .tint(Color(hex: metric.colorHex))
                    HStack {
                        Text(metric.lowLabel)
                        Spacer()
                        Text(metric.highLabel)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

        case .number, .counter, .duration:
            Section(metric.prompt) {
                HStack {
                    TextField("Value", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    if !metric.unit.isEmpty {
                        Text(metric.unit).foregroundStyle(.secondary)
                    }
                }
                Stepper("Change by \(metric.stepValue.formatted())", value: $amount, in: metric.minimumValue...metric.maximumValue, step: max(0.01, metric.stepValue))
            }

        case .yesNo:
            Section(metric.prompt) {
                Picker("Answer", selection: $amount) {
                    Text(metric.noLabel).tag(0.0)
                    Text(metric.yesLabel).tag(1.0)
                }
                .pickerStyle(.segmented)
            }

        case .choice:
            Section(metric.prompt) {
                Picker("Choose one", selection: $textValue) {
                    Text("Choose…").tag("")
                    ForEach(metric.choices, id: \.self) { choice in
                        Text(choice).tag(choice)
                    }
                }
            }

        case .multiChoice:
            Section(metric.prompt) {
                ForEach(metric.choices, id: \.self) { choice in
                    Toggle(choice, isOn: Binding(
                        get: { selectedChoices.contains(choice) },
                        set: { selected in
                            if selected { selectedChoices.insert(choice) }
                            else { selectedChoices.remove(choice) }
                        }
                    ))
                }
            }

        case .time:
            Section {
                Label(timestamp.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar.badge.clock")
                    .font(.headline)
            } header: {
                Text(metric.prompt)
            } footer: {
                Text("The date and time above are the value for this tracker.")
            }

        case .medication:
            Section(metric.prompt) {
                Picker("Medication", selection: $selectedMedicationID) {
                    Text("Choose…").tag(nil as UUID?)
                    ForEach(metric.medications) { medication in
                        Text(medication.name).tag(medication.id as UUID?)
                    }
                }
                .onChange(of: selectedMedicationID) { _, newID in
                    guard entry == nil, let medication = metric.medications.first(where: { $0.id == newID }) else { return }
                    amount = medication.defaultDose
                    doseUnit = medication.unit
                }
                HStack {
                    TextField("Dose", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Unit", text: $doseUnit)
                }
            }

        case .event:
            Section(metric.prompt) {
                TextField("Optional detail, such as what happened", text: $textValue, axis: .vertical)
                    .lineLimit(2...6)
            }

        case .note:
            Section(metric.prompt) {
                TextEditor(text: $textValue)
                    .frame(minHeight: 140)
            }
        }
    }

    private func dateShortcut(_ title: String, date: Date) -> some View {
        Button(title) {
            timestamp = min(.now, date)
            Haptics.selected()
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .tint(Color(hex: metric.colorHex))
    }

    private var earlierToday: Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let suggested = calendar.date(byAdding: .hour, value: 9, to: start) ?? start
        return min(.now, suggested)
    }

    private func save() {
        let target = entry ?? MetricEntry(metric: metric)
        if entry == nil { modelContext.insert(target) }

        target.timestamp = timestamp
        target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        target.updatedAt = entry == nil ? nil : .now
        target.valueUnit = nil

        switch metric.kind {
        case .scale, .number, .counter, .duration, .yesNo:
            target.numericValue = amount
            target.textValue = ""
        case .choice:
            target.textValue = textValue
            target.numericValue = Double((metric.choices.firstIndex(of: textValue) ?? 0) + 1)
        case .multiChoice:
            target.selectedChoices = metric.choices.filter(selectedChoices.contains)
            target.numericValue = 1
        case .time:
            let components = Calendar.current.dateComponents([.hour, .minute], from: timestamp)
            target.numericValue = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
            target.textValue = ""
        case .medication:
            let medication = metric.medications.first { $0.id == selectedMedicationID }
            target.numericValue = amount
            target.textValue = medication?.name ?? textValue
            target.valueUnit = doseUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        case .event:
            target.numericValue = 1
            target.textValue = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        case .note:
            target.numericValue = 1
            target.textValue = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        metric.lastUsedAt = .now
        try? modelContext.save()
        Haptics.logged()
        dismiss()
    }
}

