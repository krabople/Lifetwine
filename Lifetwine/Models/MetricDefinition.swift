import Foundation
import SwiftData

enum MetricKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case scale
    case number
    case counter
    case duration
    case yesNo
    case choice
    case multiChoice
    case time
    case medication
    case event
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scale: "Rating"
        case .number: "Amount or measurement"
        case .counter: "One-tap counter"
        case .duration: "Duration"
        case .yesNo: "Yes or no"
        case .choice: "Pick one option"
        case .multiChoice: "Pick several options"
        case .time: "Date and time"
        case .medication: "Medication and dose"
        case .event: "One-tap event"
        case .note: "Text or note"
        }
    }

    var explanation: String {
        switch self {
        case .scale: "Tap a point on a scale you define"
        case .number: "Record any amount, measurement, dose or quantity"
        case .counter: "Add a fixed amount with one tap"
        case .duration: "Record minutes or hours"
        case .yesNo: "Two labels you define, such as Taken / Skipped"
        case .choice: "Pick one item from an unlimited list"
        case .multiChoice: "Pick any number from your own list"
        case .time: "Record when something happened, now or in the past"
        case .medication: "Choose a medication, then record its dose and unit"
        case .event: "Record that anything happened with one tap"
        case .note: "Capture words, details, symptoms, food or anything else"
        }
    }

    var defaultIcon: String {
        switch self {
        case .scale: "slider.horizontal.3"
        case .number: "number"
        case .counter: "plus.circle.fill"
        case .duration: "timer"
        case .yesNo: "checkmark.circle"
        case .choice: "square.grid.2x2"
        case .multiChoice: "checklist"
        case .time: "clock"
        case .medication: "pills.fill"
        case .event: "bolt.circle.fill"
        case .note: "text.alignleft"
        }
    }
}

struct MedicationOption: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var defaultDose: Double
    var unit: String

    init(id: UUID = UUID(), name: String = "", defaultDose: Double = 1, unit: String = "mg") {
        self.id = id
        self.name = name
        self.defaultDose = defaultDose
        self.unit = unit
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
    // Optional additions allow existing stores to migrate without losing data.
    var promptText: String?
    var quickValuesText: String?
    var positiveLabel: String?
    var negativeLabel: String?
    var lastUsedAt: Date?
    var structuredOptionsJSON: String?
    var remindersEnabled: Bool?
    var reminderTimesText: String?
    var reminderWeekdaysText: String?
    var reminderMessageText: String?

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
        promptText: String = "",
        quickValues: [Double] = [],
        positiveLabel: String = "Yes",
        negativeLabel: String = "No",
        lastUsedAt: Date? = nil,
        medications: [MedicationOption] = [],
        remindersEnabled: Bool = false,
        reminderTimes: [Int] = [],
        reminderWeekdays: Set<Int> = [],
        reminderMessage: String = "",
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
        self.promptText = promptText
        self.quickValuesText = quickValues.map { String($0) }.joined(separator: "|")
        self.positiveLabel = positiveLabel
        self.negativeLabel = negativeLabel
        self.lastUsedAt = lastUsedAt
        self.structuredOptionsJSON = try? String(data: JSONEncoder().encode(medications), encoding: .utf8)
        self.remindersEnabled = remindersEnabled
        self.reminderTimesText = reminderTimes.map(String.init).joined(separator: "|")
        self.reminderWeekdaysText = reminderWeekdays.sorted().map(String.init).joined(separator: "|")
        self.reminderMessageText = reminderMessage
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

    var quickValues: [Double] {
        get { (quickValuesText ?? "").split(separator: "|").compactMap { Double($0) } }
        set { quickValuesText = newValue.map { String($0) }.joined(separator: "|") }
    }

    var prompt: String {
        let clean = (promptText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? kind.explanation : clean
    }

    var yesLabel: String {
        let clean = (positiveLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Yes" : clean
    }

    var noLabel: String {
        let clean = (negativeLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "No" : clean
    }

    var medications: [MedicationOption] {
        get {
            guard let data = (structuredOptionsJSON ?? "").data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([MedicationOption].self, from: data)) ?? []
        }
        set {
            structuredOptionsJSON = try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)
        }
    }

    var hasReminders: Bool {
        get { remindersEnabled ?? false }
        set { remindersEnabled = newValue }
    }

    var reminderMinutes: [Int] {
        get { (reminderTimesText ?? "").split(separator: "|").compactMap { Int($0) } }
        set { reminderTimesText = newValue.map(String.init).joined(separator: "|") }
    }

    var reminderWeekdays: Set<Int> {
        get { Set((reminderWeekdaysText ?? "").split(separator: "|").compactMap { Int($0) }) }
        set { reminderWeekdaysText = newValue.sorted().map(String.init).joined(separator: "|") }
    }

    var reminderMessage: String {
        get { reminderMessageText ?? "" }
        set { reminderMessageText = newValue }
    }

    var supportsCorrelation: Bool { kind != .note }
}
