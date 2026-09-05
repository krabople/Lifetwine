import Foundation
import WidgetKit

enum WidgetSnapshotStore {
    static let suiteName = "group.com.krabople.lifetwine"
    static let snapshotKey = "LifetwineWidgetChartSnapshot"

    @MainActor
    static func refresh(metrics: [MetricDefinition], entries: [MetricEntry]) {
        let activeMetrics = metrics.filter { !$0.isArchived && $0.supportsCorrelation }
        let selectedIDs = Set(activeMetrics.map(\.id))
        let chartPoints = ChartDataBuilder.makePoints(
            metrics: activeMetrics,
            entries: entries,
            selectedIDs: selectedIDs,
            days: 90
        )
        let byMetric = Dictionary(grouping: chartPoints, by: \.metricID)
        let snapshot = WidgetChartSnapshot(
            updatedAt: .now,
            trackers: activeMetrics.map { metric in
                WidgetChartTracker(
                    id: metric.id.uuidString,
                    name: metric.name,
                    colorHex: metric.colorHex,
                    isPinned: metric.isPinned,
                    points: (byMetric[metric.id] ?? []).map {
                        WidgetChartPoint(date: $0.date, normalizedValue: $0.normalizedValue)
                    }
                )
            }
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct WidgetChartSnapshot: Codable {
    let updatedAt: Date
    let trackers: [WidgetChartTracker]
}

private struct WidgetChartTracker: Codable {
    let id: String
    let name: String
    let colorHex: String
    let isPinned: Bool
    let points: [WidgetChartPoint]
}

private struct WidgetChartPoint: Codable {
    let date: Date
    let normalizedValue: Double
}
