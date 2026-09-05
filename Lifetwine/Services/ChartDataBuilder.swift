import Foundation

struct TrackerChartPoint: Identifiable, Hashable {
    let metricID: UUID
    let metricName: String
    let colorHex: String
    let unit: String
    let date: Date
    let value: Double
    let normalizedValue: Double

    var id: String { "\(metricID.uuidString)-\(date.timeIntervalSinceReferenceDate)" }
}

enum ChartDataBuilder {
    static func makePoints(
        metrics: [MetricDefinition],
        entries: [MetricEntry],
        selectedIDs: Set<UUID>,
        days: Int?,
        calendar: Calendar = .current
    ) -> [TrackerChartPoint] {
        let startDate = days.flatMap {
            calendar.date(byAdding: .day, value: -max(0, $0 - 1), to: calendar.startOfDay(for: .now))
        }
        let selectedMetrics = metrics.filter {
            selectedIDs.contains($0.id) && !$0.isArchived && $0.supportsCorrelation
        }
        var result: [TrackerChartPoint] = []

        for metric in selectedMetrics {
            let relevantEntries = entries.filter { entry in
                guard entry.metric?.id == metric.id else { return false }
                return startDate.map { entry.timestamp >= $0 } ?? true
            }
            let grouped = Dictionary(grouping: relevantEntries) {
                calendar.startOfDay(for: $0.timestamp)
            }
            let dailyValues: [(Date, Double)] = grouped.compactMap { day, dayEntries in
                guard let value = aggregate(metric: metric, entries: dayEntries) else { return nil }
                return (day, value)
            }
            .sorted { $0.0 < $1.0 }

            guard !dailyValues.isEmpty else { continue }
            let values = dailyValues.map(\.1)
            let minimum = values.min() ?? 0
            let maximum = values.max() ?? minimum
            let spread = maximum - minimum

            result.append(contentsOf: dailyValues.map { day, value in
                TrackerChartPoint(
                    metricID: metric.id,
                    metricName: metric.name,
                    colorHex: metric.colorHex,
                    unit: metric.unit,
                    date: day,
                    value: value,
                    normalizedValue: spread > 0.000_001 ? (value - minimum) / spread : 0.5
                )
            })
        }

        return result.sorted {
            if $0.date == $1.date { return $0.metricName < $1.metricName }
            return $0.date < $1.date
        }
    }

    private static func aggregate(metric: MetricDefinition, entries: [MetricEntry]) -> Double? {
        if metric.kind == .event || metric.aggregation == .count {
            return entries.isEmpty ? nil : Double(entries.count)
        }

        let values = entries.compactMap(\.numericValue)
        guard !values.isEmpty else { return nil }

        switch metric.aggregation {
        case .average:
            return values.reduce(0, +) / Double(values.count)
        case .total:
            return values.reduce(0, +)
        case .latest:
            return entries
                .filter { $0.numericValue != nil }
                .max(by: { $0.timestamp < $1.timestamp })?
                .numericValue
        case .count:
            return Double(entries.count)
        }
    }
}
