import Foundation
import SwiftData

@Model
final class MetricEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var numericValue: Double?
    var textValue: String
    var note: String
    var createdAt: Date
    var updatedAt: Date?
    var valueUnit: String?
    var isSample: Bool?
    var metric: MetricDefinition?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        numericValue: Double? = nil,
        textValue: String = "",
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        valueUnit: String? = nil,
        isSample: Bool? = nil,
        metric: MetricDefinition? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.numericValue = numericValue
        self.textValue = textValue
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.valueUnit = valueUnit
        self.isSample = isSample
        self.metric = metric
    }

    var formattedValue: String {
        guard let metric else { return textValue }

        switch metric.kind {
        case .scale:
            return numericValue.map { "\(Int($0.rounded())) / \(Int(metric.maximumValue))" } ?? "—"
        case .number, .counter:
            guard let numericValue else { return "—" }
            return "\(numericValue.formatted(.number.precision(.fractionLength(0...2))))\(metric.unit.isEmpty ? "" : " \(metric.unit)")"
        case .duration:
            guard let numericValue else { return "—" }
            if metric.unit.lowercased().hasPrefix("hour") {
                return "\(numericValue.formatted(.number.precision(.fractionLength(0...1)))) hr"
            }
            let minutes = Int(numericValue.rounded())
            return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min"
        case .yesNo:
            return numericValue == 1 ? metric.yesLabel : metric.noLabel
        case .choice:
            return textValue
        case .multiChoice:
            return selectedChoices.joined(separator: ", ")
        case .time:
            guard let numericValue else { return "—" }
            let totalMinutes = Int(numericValue.rounded())
            var components = DateComponents()
            components.hour = totalMinutes / 60
            components.minute = totalMinutes % 60
            let date = Calendar.current.date(from: components) ?? timestamp
            return date.formatted(date: .omitted, time: .shortened)
        case .medication:
            let dose = numericValue?.formatted(.number.precision(.fractionLength(0...2))) ?? "—"
            let unit = (valueUnit ?? metric.unit).trimmingCharacters(in: .whitespacesAndNewlines)
            return [textValue, unit.isEmpty ? dose : "\(dose) \(unit)"].filter { !$0.isEmpty }.joined(separator: " • ")
        case .event, .note:
            return textValue.isEmpty ? "Logged" : textValue
        }
    }

    var selectedChoices: [String] {
        get {
            textValue
                .split(separator: "\u{1F}")
                .map(String.init)
                .filter { !$0.isEmpty }
        }
        set { textValue = newValue.joined(separator: "\u{1F}") }
    }
}

