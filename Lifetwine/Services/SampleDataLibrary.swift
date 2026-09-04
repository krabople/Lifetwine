import Foundation
import SwiftData

@MainActor
enum SampleDataLibrary {
    private static let installedKey = "LifetwineInstalledPatternSampleHistory"

    static func installIfNeeded(in context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<MetricEntry>())) ?? []
        if entries.contains(where: { $0.isSample == true }) {
            UserDefaults.standard.set(true, forKey: installedKey)
            return
        }
        guard !UserDefaults.standard.bool(forKey: installedKey) else { return }
        install(in: context)
    }

    static func install(in context: ModelContext) {
        let metrics = (try? context.fetch(FetchDescriptor<MetricDefinition>())) ?? []
        var byName: [String: MetricDefinition] = [:]
        for metric in metrics where byName[metric.name] == nil {
            byName[metric.name] = metric
        }
        guard let sleep = byName["Sleep"],
              let energy = byName["Energy"],
              let mood = byName["Mood"],
              let exercise = byName["Exercise"],
              let mealTime = byName["Meal time"],
              let water = byName["Water"] else { return }

        let existing = (try? context.fetch(FetchDescriptor<MetricEntry>())) ?? []
        for entry in existing where entry.isSample == true { context.delete(entry) }

        let energyValues: [Double] = [2, 5, 3, 4, 1, 5, 2, 4, 3, 5, 1, 4, 2, 5, 3, 1, 4, 5, 2, 3, 4]
        let exerciseValues: [Double] = [0, 45, 10, 30, 0, 60, 15, 40, 20, 55, 0, 35, 10, 65, 25, 0, 45, 60, 15, 25, 40]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        for index in energyValues.indices {
            guard let day = calendar.date(byAdding: .day, value: index - energyValues.count, to: today) else { continue }
            let energyValue = energyValues[index]
            let sleepHours = 4.5 + (energyValue * 0.85)
            let moodValue = min(5, 1.5 + exerciseValues[index] / 16)
            let waterValue = 1_000 + Double((index * 350) % 1_500)

            insert(metric: sleep, date: date(day, hour: 7), numeric: sleepHours, context: context)
            insert(metric: energy, date: date(day, hour: 17), numeric: energyValue, context: context)
            insert(metric: exercise, date: date(day, hour: 18), numeric: exerciseValues[index], context: context)
            insert(metric: mood, date: date(day, hour: 20), numeric: moodValue, context: context)
            insert(metric: water, date: date(day, hour: 21), numeric: waterValue, context: context)

            // The previous evening's later meal aligns with lower next-day energy.
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: day) {
                let minutes = 1_380 - Int(energyValue * 70)
                insert(metric: mealTime, date: date(previousDay, minutesAfterMidnight: minutes), numeric: Double(minutes), context: context)
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: installedKey)
    }

    static func remove(in context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<MetricEntry>())) ?? []
        for entry in entries where entry.isSample == true { context.delete(entry) }
        try? context.save()
    }

    private static func insert(metric: MetricDefinition, date: Date, numeric: Double, context: ModelContext) {
        context.insert(MetricEntry(timestamp: date, numericValue: numeric, isSample: true, metric: metric))
    }

    private static func date(_ day: Date, hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private static func date(_ day: Date, minutesAfterMidnight: Int) -> Date {
        let safeMinutes = min(1_439, max(0, minutesAfterMidnight))
        return Calendar.current.date(
            bySettingHour: safeMinutes / 60,
            minute: safeMinutes % 60,
            second: 0,
            of: day
        ) ?? day
    }
}

