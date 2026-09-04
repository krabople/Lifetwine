import Foundation
import SwiftData

@MainActor
enum StarterLibrary {
    static func installIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<MetricDefinition>()
        let existing = (try? context.fetch(descriptor)) ?? []
        if !existing.isEmpty {
            upgradeStarterConfiguration(existing, in: context)
            return
        }

        let starters: [MetricDefinition] = [
            MetricDefinition(
                name: "Mood", kind: .scale, symbol: "face.smiling", colorHex: "A379C9",
                lowLabel: "Low", highLabel: "Great", role: .outcome, sortOrder: 0
            ),
            MetricDefinition(
                name: "Energy", kind: .scale, symbol: "bolt.fill", colorHex: "EDA84F",
                lowLabel: "Empty", highLabel: "Full", role: .outcome, sortOrder: 1
            ),
            MetricDefinition(
                name: "Sleep", kind: .duration, unit: "hours", symbol: "moon.stars.fill", colorHex: "5B68D8",
                minimumValue: 0, maximumValue: 14, stepValue: 0.5, defaultValue: 8,
                aggregation: .average, role: .influence, sortOrder: 2
            ),
            MetricDefinition(
                name: "Meal time", kind: .time, symbol: "fork.knife", colorHex: "EA796B",
                minimumValue: 0, maximumValue: 1439, stepValue: 15, defaultValue: 720,
                aggregation: .latest, role: .influence, sortOrder: 3
            ),
            MetricDefinition(
                name: "Water", kind: .number, unit: "ml", symbol: "drop.fill", colorHex: "4E9CCB",
                minimumValue: 0, maximumValue: 5000, stepValue: 250, defaultValue: 250,
                aggregation: .total, role: .influence, sortOrder: 4
            ),
            MetricDefinition(
                name: "Exercise", kind: .duration, unit: "minutes", symbol: "figure.run", colorHex: "58B89C",
                minimumValue: 0, maximumValue: 300, stepValue: 5, defaultValue: 30,
                aggregation: .total, role: .influence, sortOrder: 5
            ),
            MetricDefinition(
                name: "Stress", kind: .scale, symbol: "waveform.path.ecg", colorHex: "EA796B",
                lowLabel: "Calm", highLabel: "Intense", role: .outcome, isPinned: false, sortOrder: 6
            ),
            MetricDefinition(
                name: "Caffeine", kind: .number, unit: "mg", symbol: "cup.and.saucer.fill", colorHex: "9A7355",
                minimumValue: 0, maximumValue: 1000, stepValue: 20, defaultValue: 80,
                aggregation: .total, role: .influence, isPinned: false, sortOrder: 7,
                quickValues: [40, 80, 120, 200]
            ),
            MetricDefinition(
                name: "Medication", kind: .medication, symbol: "pills.fill", colorHex: "5B7CFA",
                aggregation: .total, role: .influence, isPinned: false, sortOrder: 8
            ),
            MetricDefinition(
                name: "Meal details", kind: .note, symbol: "takeoutbag.and.cup.and.straw.fill", colorHex: "D48A5A",
                aggregation: .count, role: .influence, isPinned: false, sortOrder: 9
            ),
            MetricDefinition(
                name: "Headache", kind: .yesNo, symbol: "brain.head.profile", colorHex: "D06F91",
                minimumValue: 0, maximumValue: 1, defaultValue: 0,
                aggregation: .latest, role: .outcome, isPinned: false, sortOrder: 10
            )
        ]

        starters.forEach(context.insert)
        try? context.save()
    }

    private static func upgradeStarterConfiguration(_ metrics: [MetricDefinition], in context: ModelContext) {
        if let medication = metrics.first(where: { $0.name == "Medication" && $0.kind == .note && $0.entries.isEmpty }) {
            medication.kind = .medication
            medication.aggregation = .total
            medication.promptText = "What did you take?"
        }
        if let caffeine = metrics.first(where: { $0.name == "Caffeine" && $0.quickValues.isEmpty }) {
            caffeine.quickValues = [40, 80, 120, 200]
        }
        try? context.save()
    }
}

enum MetricTemplateLibrary {
    struct Template: Identifiable {
        let id = UUID()
        let name: String
        let kind: MetricKind
        let unit: String
        let symbol: String
        let colorHex: String
        let minimum: Double
        let maximum: Double
        let step: Double
        let defaultValue: Double
        let aggregation: MetricAggregation
        let role: MetricRole
        let choices: [String]
        let quickValues: [Double]
        let prompt: String
        let positiveLabel: String
        let negativeLabel: String

        init(
            name: String,
            kind: MetricKind,
            unit: String,
            symbol: String,
            colorHex: String,
            minimum: Double,
            maximum: Double,
            step: Double,
            defaultValue: Double,
            aggregation: MetricAggregation,
            role: MetricRole,
            choices: [String] = [],
            quickValues: [Double] = [],
            prompt: String = "",
            positiveLabel: String = "Yes",
            negativeLabel: String = "No"
        ) {
            self.name = name
            self.kind = kind
            self.unit = unit
            self.symbol = symbol
            self.colorHex = colorHex
            self.minimum = minimum
            self.maximum = maximum
            self.step = step
            self.defaultValue = defaultValue
            self.aggregation = aggregation
            self.role = role
            self.choices = choices
            self.quickValues = quickValues
            self.prompt = prompt
            self.positiveLabel = positiveLabel
            self.negativeLabel = negativeLabel
        }
    }

    static let suggestions: [Template] = [
        Template(name: "Pain", kind: .scale, unit: "", symbol: "bandage.fill", colorHex: "EA796B", minimum: 1, maximum: 10, step: 1, defaultValue: 5, aggregation: .average, role: .outcome),
        Template(name: "Anxiety", kind: .scale, unit: "", symbol: "wind", colorHex: "A379C9", minimum: 1, maximum: 5, step: 1, defaultValue: 3, aggregation: .average, role: .outcome),
        Template(name: "Screen time", kind: .duration, unit: "minutes", symbol: "iphone", colorHex: "5B68D8", minimum: 0, maximum: 720, step: 15, defaultValue: 60, aggregation: .total, role: .influence),
        Template(name: "Alcohol", kind: .number, unit: "drinks", symbol: "wineglass.fill", colorHex: "D06F91", minimum: 0, maximum: 20, step: 1, defaultValue: 1, aggregation: .total, role: .influence),
        Template(name: "Outside time", kind: .duration, unit: "minutes", symbol: "sun.max.fill", colorHex: "EDA84F", minimum: 0, maximum: 600, step: 10, defaultValue: 30, aggregation: .total, role: .influence),
        Template(name: "Digestion", kind: .scale, unit: "", symbol: "leaf.fill", colorHex: "58B89C", minimum: 1, maximum: 5, step: 1, defaultValue: 3, aggregation: .average, role: .outcome),
        Template(name: "Medication", kind: .medication, unit: "", symbol: "pills.fill", colorHex: "5B68D8", minimum: 0, maximum: 10_000, step: 1, defaultValue: 1, aggregation: .total, role: .influence, prompt: "What did you take?"),
        Template(name: "Symptoms", kind: .multiChoice, unit: "", symbol: "cross.case.fill", colorHex: "D06F91", minimum: 0, maximum: 100, step: 1, defaultValue: 1, aggregation: .latest, role: .outcome, choices: ["Headache", "Nausea", "Dizziness", "Brain fog"]),
        Template(name: "Meal type", kind: .choice, unit: "", symbol: "fork.knife", colorHex: "EA796B", minimum: 1, maximum: 10, step: 1, defaultValue: 1, aggregation: .latest, role: .influence, choices: ["Breakfast", "Lunch", "Dinner", "Snack"]),
        Template(name: "Coffee", kind: .number, unit: "mg caffeine", symbol: "cup.and.saucer.fill", colorHex: "9A7355", minimum: 0, maximum: 600, step: 20, defaultValue: 80, aggregation: .total, role: .influence, quickValues: [40, 80, 120, 200]),
        Template(name: "Woke during night", kind: .counter, unit: "times", symbol: "moon.zzz.fill", colorHex: "5B68D8", minimum: 0, maximum: 50, step: 1, defaultValue: 1, aggregation: .total, role: .influence),
        Template(name: "Took supplements", kind: .yesNo, unit: "", symbol: "pills.fill", colorHex: "58B89C", minimum: 0, maximum: 1, step: 1, defaultValue: 1, aggregation: .latest, role: .influence, prompt: "Did you take them?", positiveLabel: "Taken", negativeLabel: "Skipped"),
        Template(name: "Bedtime", kind: .time, unit: "", symbol: "bed.double.fill", colorHex: "7C63C8", minimum: 0, maximum: 1439, step: 15, defaultValue: 1380, aggregation: .latest, role: .influence),
        Template(name: "Headache started", kind: .event, unit: "", symbol: "brain.head.profile", colorHex: "D06F91", minimum: 0, maximum: 100, step: 1, defaultValue: 1, aggregation: .count, role: .outcome),
        Template(name: "Weight", kind: .number, unit: "kg", symbol: "scalemass.fill", colorHex: "4E9CCB", minimum: 0, maximum: 500, step: 0.1, defaultValue: 70, aggregation: .latest, role: .outcome),
        Template(name: "Social contact", kind: .duration, unit: "minutes", symbol: "person.2.fill", colorHex: "A379C9", minimum: 0, maximum: 1440, step: 15, defaultValue: 60, aggregation: .total, role: .influence),
        Template(name: "Where I worked", kind: .choice, unit: "", symbol: "briefcase.fill", colorHex: "59636E", minimum: 1, maximum: 10, step: 1, defaultValue: 1, aggregation: .latest, role: .influence, choices: ["Home", "Office", "Elsewhere"]),
        Template(name: "Daily reflection", kind: .note, unit: "", symbol: "book.fill", colorHex: "3F7D58", minimum: 0, maximum: 100, step: 1, defaultValue: 1, aggregation: .count, role: .both)
    ]
}

