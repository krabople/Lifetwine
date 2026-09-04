import Foundation
import SwiftData

@MainActor
enum StarterLibrary {
    static func installIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<MetricDefinition>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

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
                aggregation: .total, role: .influence, isPinned: false, sortOrder: 7
            ),
            MetricDefinition(
                name: "Medication", kind: .note, symbol: "pills.fill", colorHex: "5B7CFA",
                aggregation: .count, role: .influence, isPinned: false, sortOrder: 8
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
    }

    static let suggestions: [Template] = [
        Template(name: "Pain", kind: .scale, unit: "", symbol: "bandage.fill", colorHex: "EA796B", minimum: 1, maximum: 10, step: 1, defaultValue: 5, aggregation: .average, role: .outcome),
        Template(name: "Anxiety", kind: .scale, unit: "", symbol: "wind", colorHex: "A379C9", minimum: 1, maximum: 5, step: 1, defaultValue: 3, aggregation: .average, role: .outcome),
        Template(name: "Screen time", kind: .duration, unit: "minutes", symbol: "iphone", colorHex: "5B68D8", minimum: 0, maximum: 720, step: 15, defaultValue: 60, aggregation: .total, role: .influence),
        Template(name: "Alcohol", kind: .number, unit: "drinks", symbol: "wineglass.fill", colorHex: "D06F91", minimum: 0, maximum: 20, step: 1, defaultValue: 1, aggregation: .total, role: .influence),
        Template(name: "Outside time", kind: .duration, unit: "minutes", symbol: "sun.max.fill", colorHex: "EDA84F", minimum: 0, maximum: 600, step: 10, defaultValue: 30, aggregation: .total, role: .influence),
        Template(name: "Digestion", kind: .scale, unit: "", symbol: "leaf.fill", colorHex: "58B89C", minimum: 1, maximum: 5, step: 1, defaultValue: 3, aggregation: .average, role: .outcome)
    ]
}

