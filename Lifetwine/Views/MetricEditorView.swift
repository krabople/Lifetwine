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
    @State private var choicesInput: String
    @State private var aggregation: MetricAggregation
    @State private var role: MetricRole
    @State private var isPinned: Bool

    private let colors = ["5B68D8", "A379C9", "EA796B", "EDA84F", "58B89C", "4E9CCB", "D06F91", "9A7355"]
    private let symbols = ["sparkles", "heart.fill", "face.smiling", "bolt.fill", "moon.stars.fill", "fork.knife", "drop.fill", "figure.run", "pills.fill", "brain.head.profile", "leaf.fill", "cup.and.saucer.fill", "timer", "sun.max.fill", "bed.double.fill", "cross.case.fill"]

    init(metric: MetricDefinition?) {
        self.metric = metric
        _name = State(initialValue: metric?.name ?? "")
        _kind = State(initialValue: metric?.kind ?? .scale)
        _unit = State(initialValue: metric?.unit ?? "")
        _symbol = State(initialValue: metric?.symbol ?? "sparkles")
        _colorHex = State(initialValue: metric?.colorHex ?? "5B68D8")
        _minimum = State(initialValue: metric?.minimumValue ?? 1)
        _maximum = State(initialValue: metric?.maximumValue ?? 5)
        _step = State(initialValue: metric?.stepValue ?? 1)
        _defaultValue = State(initialValue: metric?.defaultValue ?? 3)
        _lowLabel = State(initialValue: metric?.lowLabel ?? "Low")
        _highLabel = State(initialValue: metric?.highLabel ?? "High")
        _choicesInput = State(initialValue: metric?.choices.joined(separator: ", ") ?? "")
        _aggregation = State(initialValue: metric?.aggregation ?? .average)
        _role = State(initialValue: metric?.role ?? .both)
        _isPinned = State(initialValue: metric?.isPinned ?? true)
    }

    private var parsedChoices: [String] {
        choicesInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        minimum < maximum && step > 0 &&
        (kind != .choice || parsedChoices.count >= 2)
    }

    var body: some View {
        NavigationStack {
            Form {
                if metric == nil {
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
                                        .frame(width: 92, height: 70, alignment: .leading)
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
                        Text("Popular ideas")
                    }
                }

                Section("Basics") {
                    TextField("Tracker name", text: $name)
                    Picker("How do you log it?", selection: $kind) {
                        ForEach(MetricKind.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Toggle("Show in Quick log", isOn: $isPinned)
                }

                Section("Look") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                Button {
                                    colorHex = color
                                    Haptics.selected()
                                } label: {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 30, height: 30)
                                        .overlay {
                                            if colorHex == color {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.white)
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

                valueSettings

                Section {
                    Picker("Use in patterns as", selection: $role) {
                        ForEach(MetricRole.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    if kind != .note {
                        Picker("Combine same-day logs", selection: $aggregation) {
                            ForEach(MetricAggregation.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    }
                } header: {
                    Text("Patterns")
                } footer: {
                    Text("This helps Lifetwine test sensible directions, such as sleep affecting energy.")
                }
            }
            .navigationTitle(metric == nil ? "New tracker" : "Edit tracker")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: kind) { _, newKind in configureDefaults(for: newKind) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(metric == nil ? "Add" : "Save") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private var valueSettings: some View {
        switch kind {
        case .scale:
            Section("Scale") {
                HStack {
                    TextField("Minimum", value: $minimum, format: .number).keyboardType(.decimalPad)
                    TextField("Maximum", value: $maximum, format: .number).keyboardType(.decimalPad)
                }
                HStack {
                    TextField("Low label", text: $lowLabel)
                    TextField("High label", text: $highLabel)
                }
            }
        case .number, .duration:
            Section("Values") {
                TextField("Unit (optional)", text: $unit)
                TextField("Starting amount", value: $defaultValue, format: .number).keyboardType(.decimalPad)
                TextField("Button step", value: $step, format: .number).keyboardType(.decimalPad)
                HStack {
                    TextField("Minimum", value: $minimum, format: .number).keyboardType(.decimalPad)
                    TextField("Maximum", value: $maximum, format: .number).keyboardType(.decimalPad)
                }
            }
        case .choice:
            Section {
                TextField("Home, work, travelling", text: $choicesInput, axis: .vertical)
            } header: {
                Text("Choices")
            } footer: {
                Text("Separate choices with commas. Add at least two.")
            }
        case .yesNo, .time, .note:
            EmptyView()
        }
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
        Haptics.selected()
    }

    private func configureDefaults(for kind: MetricKind) {
        symbol = kind.defaultIcon
        switch kind {
        case .scale:
            minimum = 1; maximum = 5; step = 1; defaultValue = 3; aggregation = .average
        case .number:
            minimum = 0; maximum = 100; step = 1; defaultValue = 1; aggregation = .total
        case .duration:
            minimum = 0; maximum = 720; step = 15; defaultValue = 30; unit = "minutes"; aggregation = .total
        case .yesNo:
            minimum = 0; maximum = 1; step = 1; defaultValue = 0; aggregation = .latest
        case .choice:
            minimum = 1; maximum = 10; step = 1; defaultValue = 1; aggregation = .latest
        case .time:
            minimum = 0; maximum = 1439; step = 15; defaultValue = 720; aggregation = .latest
        case .note:
            minimum = 0; maximum = 100; step = 1; defaultValue = 1; aggregation = .count; role = .influence
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let metric {
            metric.name = cleanName
            metric.kind = kind
            metric.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
            metric.symbol = symbol
            metric.colorHex = colorHex
            metric.minimumValue = minimum
            metric.maximumValue = maximum
            metric.stepValue = step
            metric.defaultValue = min(maximum, max(minimum, defaultValue))
            metric.lowLabel = lowLabel
            metric.highLabel = highLabel
            metric.choices = parsedChoices
            metric.aggregation = aggregation
            metric.role = role
            metric.isPinned = isPinned
        } else {
            let newMetric = MetricDefinition(
                name: cleanName,
                kind: kind,
                unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
                symbol: symbol,
                colorHex: colorHex,
                minimumValue: minimum,
                maximumValue: maximum,
                stepValue: step,
                defaultValue: min(maximum, max(minimum, defaultValue)),
                lowLabel: lowLabel,
                highLabel: highLabel,
                choices: parsedChoices,
                aggregation: aggregation,
                role: role,
                isPinned: isPinned,
                sortOrder: ((try? modelContext.fetchCount(FetchDescriptor<MetricDefinition>())) ?? 0) + 1
            )
            modelContext.insert(newMetric)
        }
        try? modelContext.save()
        Haptics.logged()
        dismiss()
    }
}

