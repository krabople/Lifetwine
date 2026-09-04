import SwiftData
import SwiftUI

struct QuickLogCard: View {
    @Environment(\.modelContext) private var modelContext
    let metric: MetricDefinition

    @State private var amount: Double
    @State private var showingDetailedEntry = false
    @State private var showingMetricEditor = false
    @State private var entryToEdit: MetricEntry?
    @State private var lastCreatedEntry: MetricEntry?

    init(metric: MetricDefinition) {
        self.metric = metric
        _amount = State(initialValue: metric.defaultValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            control

            if let lastCreatedEntry {
                confirmation(for: lastCreatedEntry)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .lifetwineCard()
        .sheet(isPresented: $showingDetailedEntry, onDismiss: { entryToEdit = nil }) {
            EntryEditorView(metric: metric, entry: entryToEdit)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingMetricEditor) {
            MetricEditorView(metric: metric)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: metric.symbol)
                .font(.headline)
                .foregroundStyle(Color(hex: metric.colorHex))
                .frame(width: 38, height: 38)
                .background(Color(hex: metric.colorHex).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name)
                    .font(.headline)
                    .foregroundStyle(LifetwineTheme.ink)
                Text(metric.prompt)
                    .font(.caption)
                    .foregroundStyle(LifetwineTheme.secondaryInk)
                    .lineLimit(2)
            }
            Spacer()
            Menu {
                Button {
                    entryToEdit = nil
                    showingDetailedEntry = true
                } label: {
                    Label("Choose value, date and time", systemImage: "calendar.badge.clock")
                }
                Button {
                    showingMetricEditor = true
                } label: {
                    Label("Edit tracker setup", systemImage: "pencil")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .accessibilityLabel("More ways to log \(metric.name)")
        }
    }

    @ViewBuilder
    private var control: some View {
        switch metric.kind {
        case .scale:
            VStack(spacing: 8) {
                if scaleValues.count <= 7 {
                    HStack(spacing: 7) {
                        ForEach(scaleValues, id: \.self) { value in
                            scaleButton(value).frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(scaleValues, id: \.self) { value in scaleButton(value) }
                        }
                    }
                }
                HStack {
                    Text(metric.lowLabel)
                    Spacer()
                    Text(metric.highLabel)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }

        case .yesNo:
            HStack(spacing: 10) {
                quickButton(title: metric.noLabel, icon: "xmark", color: LifetwineTheme.secondaryInk) { log(numeric: 0) }
                quickButton(title: metric.yesLabel, icon: "checkmark", color: Color(hex: metric.colorHex)) { log(numeric: 1) }
            }

        case .choice:
            optionScroller(metric.choices) { index, choice in
                log(numeric: Double(index + 1), text: choice)
            }

        case .multiChoice:
            Button {
                entryToEdit = nil
                showingDetailedEntry = true
            } label: {
                Label("Choose any that apply", systemImage: "checklist")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(Color(hex: metric.colorHex))
                    .background(Color(hex: metric.colorHex).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)

        case .time:
            HStack(spacing: 10) {
                quickButton(title: "Now", icon: "clock.fill", color: Color(hex: metric.colorHex)) { logTime(.now) }
                detailedButton(title: "Earlier", icon: "calendar.badge.clock")
            }

        case .medication:
            if metric.medications.isEmpty {
                Button {
                    showingMetricEditor = true
                } label: {
                    Label("Add your medications and doses", systemImage: "pills.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(Color(hex: metric.colorHex))
                        .background(Color(hex: metric.colorHex).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(metric.medications) { medication in
                            Button {
                                log(numeric: medication.defaultDose, text: medication.name, unit: medication.unit)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(medication.name).fontWeight(.semibold)
                                    Text("\(medication.defaultDose.formatted()) \(medication.unit)")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 46)
                                .foregroundStyle(Color(hex: metric.colorHex))
                                .background(Color(hex: metric.colorHex).opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        detailedButton(title: "Other", icon: "slider.horizontal.3")
                    }
                }
            }

        case .number, .duration:
            VStack(spacing: 10) {
                if !metric.quickValues.isEmpty {
                    optionScroller(metric.quickValues) { _, value in
                        log(numeric: value)
                    }
                }
                HStack(spacing: 10) {
                    stepButton(systemName: "minus", delta: -metric.stepValue)
                    Text(formatted(amount))
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(LifetwineTheme.ink)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    stepButton(systemName: "plus", delta: metric.stepValue)
                    Button("Add") { log(numeric: amount) }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 19)
                        .frame(height: 44)
                        .background(Color(hex: metric.colorHex))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }

        case .counter:
            HStack(spacing: 10) {
                quickButton(title: "+ \(formatted(metric.defaultValue))", icon: "plus", color: Color(hex: metric.colorHex)) {
                    log(numeric: metric.defaultValue)
                }
                detailedButton(title: "Other", icon: "slider.horizontal.3")
            }

        case .event:
            HStack(spacing: 10) {
                quickButton(title: "Log now", icon: "checkmark.circle.fill", color: Color(hex: metric.colorHex)) {
                    log(numeric: 1)
                }
                detailedButton(title: "Details", icon: "text.badge.plus")
            }

        case .note:
            Button {
                entryToEdit = nil
                showingDetailedEntry = true
            } label: {
                Label("Write or dictate a note", systemImage: "mic.badge.plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(Color(hex: metric.colorHex))
                    .background(Color(hex: metric.colorHex).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func optionScroller<T: Hashable>(_ values: [T], action: @escaping (Int, T) -> Void) -> some View where T: CustomStringConvertible {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Button(display(value)) { action(index, value) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: metric.colorHex))
                        .padding(.horizontal, 15)
                        .frame(minHeight: 42)
                        .background(Color(hex: metric.colorHex).opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func display<T>(_ value: T) -> String {
        if let number = value as? Double { return formatted(number) }
        return String(describing: value)
    }

    private func detailedButton(title: String, icon: String) -> some View {
        Button {
            entryToEdit = nil
            showingDetailedEntry = true
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .frame(minWidth: 82, minHeight: 44)
                .padding(.horizontal, 8)
                .foregroundStyle(Color(hex: metric.colorHex))
                .background(Color(hex: metric.colorHex).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func confirmation(for entry: MetricEntry) -> some View {
        HStack(spacing: 10) {
            Label("Added", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(LifetwineTheme.mint)
            Spacer()
            Button("Change time") {
                entryToEdit = entry
                showingDetailedEntry = true
            }
            Button("Undo") { undo(entry) }
                .foregroundStyle(LifetwineTheme.coral)
        }
        .font(.caption.weight(.semibold))
        .padding(.top, 2)
    }

    private func quickButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(color)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func stepButton(systemName: String, delta: Double) -> some View {
        Button {
            amount = min(metric.maximumValue, max(metric.minimumValue, amount + delta))
            Haptics.selected()
        } label: {
            Image(systemName: systemName)
                .font(.headline)
                .frame(width: 42, height: 42)
                .foregroundStyle(Color(hex: metric.colorHex))
                .background(Color(hex: metric.colorHex).opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var scaleValues: [Double] {
        let interval = max(metric.stepValue, 0.01)
        let count = Int(((metric.maximumValue - metric.minimumValue) / interval).rounded(.down)) + 1
        return (0..<max(1, min(count, 101))).map { metric.minimumValue + Double($0) * interval }
    }

    private func scaleButton(_ value: Double) -> some View {
        Button { log(numeric: value) } label: {
            Text(value.formatted(.number.precision(.fractionLength(0...2))))
                .font(.subheadline.weight(.bold))
                .frame(minWidth: 42, minHeight: 40)
                .background(Color(hex: metric.colorHex).opacity(0.1))
                .foregroundStyle(Color(hex: metric.colorHex))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(metric.name), \(value.formatted()) out of \(metric.maximumValue.formatted())")
    }

    private func formatted(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...2)))
        if metric.kind == .duration && metric.unit.lowercased().hasPrefix("minute") {
            let minutes = Int(value.rounded())
            return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min"
        }
        return metric.unit.isEmpty ? number : "\(number) \(metric.unit)"
    }

    private func logTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        log(numeric: minutes, timestamp: date)
    }

    private func log(numeric: Double? = nil, text: String = "", unit: String? = nil, timestamp: Date = .now) {
        let entry = MetricEntry(timestamp: timestamp, numericValue: numeric, textValue: text, valueUnit: unit, metric: metric)
        modelContext.insert(entry)
        metric.lastUsedAt = .now
        try? modelContext.save()
        Haptics.logged()
        withAnimation(.easeOut(duration: 0.2)) { lastCreatedEntry = entry }
    }

    private func undo(_ entry: MetricEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        withAnimation { lastCreatedEntry = nil }
        Haptics.selected()
    }
}

