import Foundation
import SwiftData

enum MetricKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case scale
    case number
    case duration
    case yesNo
    case choice
    case time
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scale: "Rating"
        case .number: "Number"
        case .duration: "Duration"
        case .yesNo: "Yes or no"
        case .choice: "Choice"
        case .time: "Time"
        case .note: "Note or event"
        }
    }

    var explanation: String {
        switch self {
        case .scale: "Tap a point on a simple scale"
        case .number: "Record an amount, such as water or weight"
        case .duration: "Record minutes or hours"
        case .yesNo: "A quick two-option check-in"
        case .choice: "Pick from your own list"
        case .time: "Record when something happened"
        case .note: "Capture words, details, or an event"
        }
    }

    var defaultIcon: String {
        switch self {
        case .scale: "slider.horizontal.3"
        case .number: "number"
        case .duration: "timer"
        case .yesNo: "checkmark.circle"
        case .choice: "square.grid.2x2"
        case .time: "clock"
        case .note: "text.alignleft"
        }
    }
}

enum MetricAggregation: String, Codable, CaseIterable, Identifiable, Sendable {
    case average
    case total
    case latest
    case count

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum MetricRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case influence
    case outcome
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .influence: "Something I do"
        case .outcome: "Something I feel"
        case .both: "Could be either"
        }
    }
}

@Model
final class MetricDefinition {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var unit: String
    var symbol: String
    var colorHex: String
    var minimumValue: Double
    var maximumValue: Double
    var stepValue: Double
    var defaultValue: Double
    var lowLabel: String
    var highLabel: String
    var choicesText: String
    var aggregationRaw: String
    var roleRaw: String
    var isPinned: Bool
    var sortOrder: Int
    var createdAt: Date
    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \MetricEntry.metric)
    var entries: [MetricEntry]

    init(
        id: UUID = UUID(),
        name: String,
        kind: MetricKind,
        unit: String = "",
        symbol: String? = nil,
        colorHex: String = "5B7CFA",
        minimumValue: Double = 1,
        maximumValue: Double = 5,
        stepValue: Double = 1,
        defaultValue: Double = 1,
        lowLabel: String = "Low",
        highLabel: String = "High",
        choices: [String] = [],
        aggregation: MetricAggregation = .average,
        role: MetricRole = .both,
        isPinned: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        isArchived: Bool = false,
        entries: [MetricEntry] = []
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.unit = unit
        self.symbol = symbol ?? kind.defaultIcon
        self.colorHex = colorHex
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.stepValue = stepValue
        self.defaultValue = defaultValue
        self.lowLabel = lowLabel
        self.highLabel = highLabel
        self.choicesText = choices.joined(separator: "|")
        self.aggregationRaw = aggregation.rawValue
        self.roleRaw = role.rawValue
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.entries = entries
    }

    var kind: MetricKind {
        get { MetricKind(rawValue: kindRaw) ?? .number }
        set { kindRaw = newValue.rawValue }
    }

    var aggregation: MetricAggregation {
        get { MetricAggregation(rawValue: aggregationRaw) ?? .average }
        set { aggregationRaw = newValue.rawValue }
    }

    var role: MetricRole {
        get { MetricRole(rawValue: roleRaw) ?? .both }
        set { roleRaw = newValue.rawValue }
    }

    var choices: [String] {
        get { choicesText.split(separator: "|").map(String.init) }
        set { choicesText = newValue.joined(separator: "|") }
    }

    var supportsCorrelation: Bool { kind != .note || aggregation == .count }
}

