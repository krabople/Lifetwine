import SwiftData
import SwiftUI

struct QuickLogCard: View {
    @Environment(\.modelContext) private var modelContext
    let metric: MetricDefinition

    @State private var amount: Double
    @State private var textValue = ""
    @State private var chosenTime = Date.now
    @State private var showingDetailEntry = false
    @State private var justLogged = false

    init(metric: MetricDefinition) {
        self.metric = metric
        _amount = State(initialValue: metric.defaultValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    if justLogged {
                        Label("Added", systemImage: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LifetwineTheme.mint)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        Text(prompt)
                            .font(.caption)
                            .foregroundStyle(LifetwineTheme.secondaryInk)
                    }
                }
                Spacer()
            }

            control
        }
        .padding(16)
        .lifetwineCard()
        .sheet(isPresented: $showingDetailEntry) {
            detailSheet
                .presentationDetents(metric.kind == .time ? [.medium] : [.medium, .large])
        }
    }

    private var prompt: String {
        switch metric.kind {
        case .scale: "Tap once to rate"
        case .number, .duration: "Adjust, then add"
        case .yesNo: "Tap once to answer"
        case .choice: "Tap once to choose"
        case .time: "Log now, or choose a time"
        case .note: "Capture a quick detail"
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
                            scaleButton(value)
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(scaleValues, id: \.self) { value in
                                scaleButton(value)
                            }
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
                quickButton(title: "No", icon: "xmark", color: LifetwineTheme.secondaryInk) { log(numeric: 0) }
                quickButton(title: "Yes", icon: "checkmark", color: Color(hex: metric.colorHex)) { log(numeric: 1) }
            }

        case .choice:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(Array(metric.choices.enumerated()), id: \.offset) { index, choice in
                        Button(choice) {
                            log(numeric: Double(index + 1), text: choice)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: metric.colorHex))
                        .padding(.horizontal, 15)
                        .frame(minHeight: 40)
                        .background(Color(hex: metric.colorHex).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }

        case .time:
            HStack(spacing: 10) {
                quickButton(title: "Now", icon: "clock.fill", color: Color(hex: metric.colorHex)) {
                    logTime(.now)
                }
                Button {
                    chosenTime = .now
                    showingDetailEntry = true
                } label: {
                    Image(systemName: "calendar.badge.clock")
                        .font(.headline)
                        .frame(width: 48, height: 44)
                        .background(LifetwineTheme.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose another time")
            }

        case .number, .duration:
            HStack(spacing: 10) {
                stepButton(systemName: "minus", delta: -metric.stepValue)
                Text(formattedAmount)
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

        case .note:
            Button {
                textValue = ""
                showingDetailEntry = true
            } label: {
                Label("Add a note", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(Color(hex: metric.colorHex))
                    .background(Color(hex: metric.colorHex).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
        }
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
        let count = Int(((metric.maximumValue - metric.minimumValue) / max(metric.stepValue, 1)).rounded(.down)) + 1
        return (0..<max(1, min(count, 101))).map { metric.minimumValue + Double($0) * max(metric.stepValue, 1) }
    }

    private func scaleButton(_ value: Double) -> some View {
        Button {
            log(numeric: value)
        } label: {
            Text(value.formatted(.number.precision(.fractionLength(0...1))))
                .font(.subheadline.weight(.bold))
                .frame(minWidth: 42, minHeight: 40)
                .background(Color(hex: metric.colorHex).opacity(0.1))
                .foregroundStyle(Color(hex: metric.colorHex))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(metric.name), \(value.formatted()) out of \(metric.maximumValue.formatted())")
    }

    private var formattedAmount: String {
        let number = amount.formatted(.number.precision(.fractionLength(0...2)))
        if metric.kind == .duration && metric.unit.lowercased().hasPrefix("minute") {
            let minutes = Int(amount.rounded())
            return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min"
        }
        return metric.unit.isEmpty ? number : "\(number) \(metric.unit)"
    }

    @ViewBuilder
    private var detailSheet: some View {
        NavigationStack {
            Form {
                if metric.kind == .time {
                    DatePicker("When?", selection: $chosenTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                } else {
                    Section("What would you like to remember?") {
                        TextField("Type here", text: $textValue, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    Section {
                        Text("The words stay searchable in your journal. Lifetwine compares whether and how often the event occurred; use a choice, rating or number tracker for more detailed patterns.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(metric.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingDetailEntry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if metric.kind == .time { logTime(chosenTime) }
                        else { log(numeric: 1, text: textValue.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        showingDetailEntry = false
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func logTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        log(numeric: minutes, timestamp: date)
    }

    private func log(numeric: Double? = nil, text: String = "", timestamp: Date = .now) {
        let entry = MetricEntry(timestamp: timestamp, numericValue: numeric, textValue: text, metric: metric)
        modelContext.insert(entry)
        try? modelContext.save()
        Haptics.logged()
        withAnimation(.easeOut(duration: 0.2)) { justLogged = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeIn(duration: 0.2)) { justLogged = false }
        }
    }
}

