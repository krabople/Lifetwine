import SwiftData
import SwiftUI

struct MetricEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let metric: MetricDefinition?

    @State private var name: String
    @State private var kind: MetricKind
    @State private var unit: String
    @State private var symbol: String
    @State private var colorHex: String
    @State private var minimum: Double
    @State private var maximum: Double
    @State private var step: Double
    @State private var defaultValue: Double
    @State private var lowLabel: String
    @State private var highLabel: String
    @State private var choiceDrafts: [String]
    @State private var quickValuesInput: String
    @State private var promptText: String
    @State private var positiveLabel: String
    @State private var negativeLabel: String
    @State private var medications: [MedicationOption]
    @State private var aggregation: MetricAggregation
    @State private var role: MetricRole
    @State private var isPinned: Bool
    @State private var remindersEnabled: Bool
    @State private var reminderTimes: [Date]
    @State private var useSpecificDays: Bool
    @State private var reminderWeekdays: Set<Int>
    @State private var reminderMessage: String

    private let colors = ["5B68D8", "7C63C8", "A379C9", "EA796B", "EDA84F", "58B89C", "4E9CCB", "D06F91", "9A7355", "3F7D58", "59636E", "E66A9A"]
    private let symbols = [
        "sparkles", "heart.fill", "face.smiling", "bolt.fill", "moon.stars.fill", "fork.knife",
        "drop.fill", "figure.run", "pills.fill", "brain.head.profile", "leaf.fill", "cup.and.saucer.fill",
        "timer", "sun.max.fill", "bed.double.fill", "cross.case.fill", "bandage.fill", "wind",
        "iphone", "wineglass.fill", "takeoutbag.and.cup.and.straw.fill", "waveform.path.ecg", "thermometer.medium",
        "scalemass.fill", "figure.walk", "figure.strengthtraining.traditional", "lungs.fill", "eye.fill",
        "hands.sparkles.fill", "book.fill", "music.note", "person.2.fill", "briefcase.fill", "house.fill",
        "car.fill", "cart.fill", "pawprint.fill", "star.fill", "exclamationmark.bubble.fill", "checklist"
    ]
    private let weekdayOptions = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
        (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]

    init(metric: MetricDefinition?) {
        self.metric = metric
        _name = State(initialValue: metric?.name ?? "")
        _kind = State(initialValue: metric?.kind ?? .event)
        _unit = State(initialValue: metric?.unit ?? "")
        _symbol = State(initialValue: metric?.symbol ?? MetricKind.event.defaultIcon)
        _colorHex = State(initialValue: metric?.colorHex ?? "5B68D8")
        _minimum = State(initialValue: metric?.minimumValue ?? 0)
        _maximum = State(initialValue: metric?.maximumValue ?? 100)
        _step = State(initialValue: metric?.stepValue ?? 1)
        _defaultValue = State(initialValue: metric?.defaultValue ?? 1)
        _lowLabel = State(initialValue: metric?.lowLabel ?? "Low")
        _highLabel = State(initialValue: metric?.highLabel ?? "High")
        _choiceDrafts = State(initialValue: metric?.choices ?? [])
        _quickValuesInput = State(initialValue: metric?.quickValues.map { $0.formatted() }.joined(separator: ", ") ?? "")
        _promptText = State(initialValue: metric?.promptText ?? "")
        _positiveLabel = State(initialValue: metric?.yesLabel ?? "Yes")
        _negativeLabel = State(initialValue: metric?.noLabel ?? "No")
        _medications = State(initialValue: metric?.medications ?? [])
        _aggregation = State(initialValue: metric?.aggregation ?? .count)
        _role = State(initialValue: metric?.role ?? .both)
        _isPinned = State(initialValue: metric?.isPinned ?? true)
        _remindersEnabled = State(initialValue: metric?.hasReminders ?? false)
        let calendar = Calendar.current
        let savedReminderTimes = (metric?.reminderMinutes ?? []).map { minutes in
            calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        }
        _reminderTimes = State(initialValue: savedReminderTimes)
        let savedWeekdays = metric?.reminderWeekdays ?? []
        _useSpecificDays = State(initialValue: !savedWeekdays.isEmpty)
        _reminderWeekdays = State(initialValue: savedWeekdays)
        _reminderMessage = State(initialValue: metric?.reminderMessage ?? "")
    }

    private var cleanChoices: [String] {
        choiceDrafts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var quickValues: [Double] {
        quickValuesInput
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private var canSave: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rangeIsValid = ![MetricKind.scale, .number, .counter, .duration].contains(kind) || (minimum < maximum && step > 0)
        let choicesAreValid = ![MetricKind.choice, .multiChoice].contains(kind) || cleanChoices.count >= 2
        let medicationsAreValid = kind != .medication || medications.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let remindersAreValid = !remindersEnabled || (!reminderTimes.isEmpty && (!useSpecificDays || !reminderWeekdays.isEmpty))
        return hasName && rangeIsValid && choicesAreValid && medicationsAreValid && remindersAreValid
    }

    var body: some View {
        NavigationStack {
            Form {
                if metric == nil { ideasSection }

                Section {
                    TextField("What do you want to track?", text: $name)
                    Picker("Type of answer", selection: $kind) {
                        ForEach(MetricKind.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }

                    Label(kind.explanation, systemImage: kind.defaultIcon)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Anything you choose")
                } footer: {
                    Text("There is no tracker limit. Add a separate tracker for every food, medication, symptom, habit, place, person, feeling or event you want to compare.")
                }

                Section("Fast logging") {
                    Toggle("Show on Today", isOn: $isPinned)
                    TextField("Prompt or question (optional)", text: $promptText, axis: .vertical)
                        .lineLimit(1...3)
                }

                remindersSection

                valueSettings
                lookSection
                patternsSection
            }
            .navigationTitle(metric == nil ? "Create a tracker" : "Edit tracker")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: kind) { _, newKind in configureDefaults(for: newKind) }
            .onChange(of: remindersEnabled) { _, enabled in
                guard enabled, reminderTimes.isEmpty else { return }
                reminderTimes = [Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now]
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(metric == nil ? "Create" : "Save") { Task { await save() } }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle("Remind me to log this", isOn: $remindersEnabled)

            if remindersEnabled {
                Picker("Repeat", selection: $useSpecificDays) {
                    Text("Every day").tag(false)
                    Text("Selected days").tag(true)
                }
                .pickerStyle(.segmented)

                if useSpecificDays {
                    HStack(spacing: 5) {
                        ForEach(weekdayOptions, id: \.0) { weekday, label in
                            Button {
                                if reminderWeekdays.contains(weekday) {
                                    reminderWeekdays.remove(weekday)
                                } else {
                                    reminderWeekdays.insert(weekday)
                                }
                                Haptics.selected()
                            } label: {
                                Text(label.prefix(1))
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .foregroundStyle(reminderWeekdays.contains(weekday) ? Color.white : LifetwineTheme.indigo)
                                    .background(
                                        reminderWeekdays.contains(weekday) ? LifetwineTheme.indigo : LifetwineTheme.indigo.opacity(0.1),
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(label)
                        }
                    }
                }

                ForEach(reminderTimes.indices, id: \.self) { index in
                    HStack {
                        Label("Reminder \(index + 1)", systemImage: "bell")
                        Spacer()
                        DatePicker("Time", selection: $reminderTimes[index], displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Button(role: .destructive) {
                            reminderTimes.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    reminderTimes.append(Calendar.current.date(byAdding: .hour, value: 1, to: reminderTimes.last ?? .now) ?? .now)
                } label: {
                    Label("Add another time", systemImage: "plus.circle.fill")
                }

                TextField("Custom reminder message (optional)", text: $reminderMessage, axis: .vertical)
                    .lineLimit(1...3)
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Only this tracker will trigger these private iPhone notifications. Tapping one opens it ready to log.")
        }
    }

    private var ideasSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MetricTemplateLibrary.suggestions) { template in
                        Button {
                            apply(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: template.symbol)
                                    .foregroundStyle(Color(hex: template.colorHex))
                                Text(template.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(LifetwineTheme.ink)
                            }
                            .frame(width: 100, height: 70, alignment: .leading)
                            .padding(10)
                            .background(Color(hex: template.colorHex).opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
        } header: {
            Text("Start with an idea or invent your own")
        }
    }

    @ViewBuilder
    private var valueSettings: some View {
        switch kind {
        case .scale:
            Section("Your scale") {
                HStack {
                    TextField("Minimum", value: $minimum, format: .number).keyboardType(.decimalPad)
                    TextField("Maximum", value: $maximum, format: .number).keyboardType(.decimalPad)
                    TextField("Step", value: $step, format: .number).keyboardType(.decimalPad)
                }
                HStack {
                    TextField("Low label", text: $lowLabel)
                    TextField("High label", text: $highLabel)
                }
                TextField("Starting value", value: $defaultValue, format: .number).keyboardType(.decimalPad)
            }

        case .number, .counter, .duration:
            Section {
                TextField("Unit — mg, glasses, £, km…", text: $unit)
                HStack {
                    TextField(kind == .counter ? "Amount per tap" : "Starting value", value: $defaultValue, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Step", value: $step, format: .number)
                        .keyboardType(.decimalPad)
                }
                HStack {
                    TextField("Minimum", value: $minimum, format: .number).keyboardType(.decimalPad)
                    TextField("Maximum", value: $maximum, format: .number).keyboardType(.decimalPad)
                }
                if kind != .counter {
                    TextField("One-tap values: 1, 2.5, 10", text: $quickValuesInput)
                        .keyboardType(.numbersAndPunctuation)
                }
            } header: {
                Text("Values")
            } footer: {
                Text(kind == .counter ? "One tap records the amount above. You can still enter a different amount." : "Optional one-tap values become shortcut buttons on the logging card. Separate them with commas.")
            }

        case .yesNo:
            Section("Your two answers") {
                TextField("Positive answer", text: $positiveLabel)
                TextField("Negative answer", text: $negativeLabel)
            }

        case .choice, .multiChoice:
            Section {
                ForEach(choiceDrafts.indices, id: \.self) { index in
                    HStack {
                        TextField("Option \(index + 1)", text: $choiceDrafts[index])
                        if choiceDrafts.count > 2 {
                            Button(role: .destructive) {
                                choiceDrafts.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button {
                    choiceDrafts.append("")
                } label: {
                    Label("Add another option", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Your options")
            } footer: {
                Text("Add as many options as you need. You can edit this list later.")
            }

        case .time:
            Section {
                Text("A tap records now. Detailed logging lets you choose any earlier date and time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .medication:
            Section {
                ForEach(medications.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Medication name", text: $medications[index].name)
                            Button(role: .destructive) {
                                medications.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                        HStack {
                            TextField("Usual dose", value: $medications[index].defaultDose, format: .number)
                                .keyboardType(.decimalPad)
                            TextField("Unit — mg, mL, tablets…", text: $medications[index].unit)
                        }
                    }
                }
                Button {
                    medications.append(MedicationOption())
                } label: {
                    Label("Add medication", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Your medications")
            } footer: {
                Text("Add every medication you may take, with its usual quantity and unit. The dose remains editable every time you log it.")
            }

        case .event:
            Section {
                Text("A tap records one occurrence. Examples: took medication, woke up, had a symptom, ate a snack, met someone, started work.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .note:
            Section {
                Text("Use this for anything best described in your own words. Every note remains searchable.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lookSection: some View {
        Section("Colour and symbol") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            colorHex = color
                            Haptics.selected()
                        } label: {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if colorHex == color {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 14) {
                ForEach(symbols, id: \.self) { option in
                    Button {
                        symbol = option
                        Haptics.selected()
                    } label: {
                        Image(systemName: option)
                            .foregroundStyle(symbol == option ? .white : Color(hex: colorHex))
                            .frame(width: 32, height: 32)
                            .background(symbol == option ? Color(hex: colorHex) : Color.clear, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var patternsSection: some View {
        Section {
            Picker("Use in comparisons as", selection: $role) {
                ForEach(MetricRole.allCases) { option in Text(option.title).tag(option) }
            }
            if metricKindUsesNumericPattern {
                Picker("Combine logs from the same day", selection: $aggregation) {
                    ForEach(MetricAggregation.allCases) { option in Text(option.title).tag(option) }
                }
            }
        } header: {
            Text("Pattern finding")
        } footer: {
            Text("This tells Lifetwine whether to examine this as a possible influence, an outcome, or both. It never claims that a pattern proves cause and effect.")
        }
    }

    private var metricKindUsesNumericPattern: Bool {
        ![MetricKind.choice, .multiChoice, .medication, .event, .note].contains(kind)
    }

    private func apply(_ template: MetricTemplateLibrary.Template) {
        name = template.name
        kind = template.kind
        unit = template.unit
        symbol = template.symbol
        colorHex = template.colorHex
        minimum = template.minimum
        maximum = template.maximum
        step = template.step
        defaultValue = template.defaultValue
        aggregation = template.aggregation
        role = template.role
        choiceDrafts = template.choices
        quickValuesInput = template.quickValues.map { $0.formatted() }.joined(separator: ", ")
        promptText = template.prompt
        positiveLabel = template.positiveLabel
        negativeLabel = template.negativeLabel
        if template.kind == .medication, medications.isEmpty { medications = [MedicationOption()] }
        Haptics.selected()
    }

    private func configureDefaults(for newKind: MetricKind) {
        symbol = newKind.defaultIcon
        switch newKind {
        case .scale:
            minimum = 1; maximum = 5; step = 1; defaultValue = 3; aggregation = .average
        case .number:
            minimum = 0; maximum = 10_000; step = 1; defaultValue = 1; aggregation = .total
        case .counter:
            minimum = 0; maximum = 10_000; step = 1; defaultValue = 1; aggregation = .total
        case .duration:
            minimum = 0; maximum = 1_440; step = 5; defaultValue = 30; unit = "minutes"; aggregation = .total
        case .yesNo:
            minimum = 0; maximum = 1; step = 1; defaultValue = 1; aggregation = .latest
        case .choice, .multiChoice:
            minimum = 1; maximum = 100; step = 1; defaultValue = 1; aggregation = .latest
            if choiceDrafts.count < 2 { choiceDrafts = ["", ""] }
        case .time:
            minimum = 0; maximum = 1439; step = 15; defaultValue = 720; aggregation = .latest
        case .medication:
            minimum = 0; maximum = 10_000; step = 1; defaultValue = 1; aggregation = .total; role = .influence
            if medications.isEmpty { medications = [MedicationOption()] }
        case .event, .note:
            minimum = 0; maximum = 10_000; step = 1; defaultValue = 1; aggregation = .count
        }
    }

    @MainActor
    private func save() async {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let metric {
            metric.name = cleanName
            metric.kind = kind
            metric.unit = cleanUnit
            metric.symbol = symbol
            metric.colorHex = colorHex
            metric.minimumValue = minimum
            metric.maximumValue = maximum
            metric.stepValue = step
            metric.defaultValue = min(maximum, max(minimum, defaultValue))
            metric.lowLabel = lowLabel
            metric.highLabel = highLabel
            metric.choices = cleanChoices
            metric.quickValues = quickValues
            metric.promptText = cleanPrompt
            metric.positiveLabel = positiveLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            metric.negativeLabel = negativeLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            metric.medications = medications
                .map { MedicationOption(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), defaultDose: $0.defaultDose, unit: $0.unit.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .filter { !$0.name.isEmpty }
            metric.aggregation = aggregation
            metric.role = role
            metric.isPinned = isPinned
            metric.hasReminders = remindersEnabled
            metric.reminderMinutes = reminderMinuteValues
            metric.reminderWeekdays = useSpecificDays ? reminderWeekdays : []
            metric.reminderMessage = reminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let newMetric = MetricDefinition(
                name: cleanName,
                kind: kind,
                unit: cleanUnit,
                symbol: symbol,
                colorHex: colorHex,
                minimumValue: minimum,
                maximumValue: maximum,
                stepValue: step,
                defaultValue: min(maximum, max(minimum, defaultValue)),
                lowLabel: lowLabel,
                highLabel: highLabel,
                choices: cleanChoices,
                aggregation: aggregation,
                role: role,
                isPinned: isPinned,
                sortOrder: ((try? modelContext.fetchCount(FetchDescriptor<MetricDefinition>())) ?? 0) + 1,
                promptText: cleanPrompt,
                quickValues: quickValues,
                positiveLabel: positiveLabel,
                negativeLabel: negativeLabel,
                medications: medications
                    .map { MedicationOption(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), defaultDose: $0.defaultDose, unit: $0.unit.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    .filter { !$0.name.isEmpty },
                remindersEnabled: remindersEnabled,
                reminderTimes: reminderMinuteValues,
                reminderWeekdays: useSpecificDays ? reminderWeekdays : [],
                reminderMessage: reminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(newMetric)
        }
        try? modelContext.save()
        let allMetrics = (try? modelContext.fetch(FetchDescriptor<MetricDefinition>())) ?? []
        await ReminderScheduler.rebuild(for: allMetrics)
        Haptics.logged()
        dismiss()
    }

    private var reminderMinuteValues: [Int] {
        Array(Set(reminderTimes.map {
            let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        })).sorted()
    }
}
