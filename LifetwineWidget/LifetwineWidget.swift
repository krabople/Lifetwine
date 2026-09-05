import AppIntents
import Charts
import SwiftUI
import WidgetKit

private let lifetwineSuiteName = "group.com.krabople.lifetwine"
private let lifetwineSnapshotKey = "LifetwineWidgetChartSnapshot"

private struct WidgetChartSnapshot: Codable {
    let updatedAt: Date
    let trackers: [WidgetChartTracker]

    static var current: WidgetChartSnapshot {
        guard let data = UserDefaults(suiteName: lifetwineSuiteName)?.data(forKey: lifetwineSnapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetChartSnapshot.self, from: data) else {
            return WidgetChartSnapshot(updatedAt: .now, trackers: [])
        }
        return snapshot
    }
}

private struct WidgetChartTracker: Codable, Identifiable {
    let id: String
    let name: String
    let colorHex: String
    let isPinned: Bool
    let points: [WidgetChartPoint]
}

private struct WidgetChartPoint: Codable, Identifiable {
    let date: Date
    let normalizedValue: Double
    var id: Date { date }
}

private struct WidgetTrackerEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Lifetwine tracker")
    static var defaultQuery = WidgetTrackerQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

private struct WidgetTrackerQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetTrackerEntity] {
        let requested = Set(identifiers)
        return WidgetChartSnapshot.current.trackers
            .filter { requested.contains($0.id) }
            .map { WidgetTrackerEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [WidgetTrackerEntity] {
        WidgetChartSnapshot.current.trackers.map { WidgetTrackerEntity(id: $0.id, name: $0.name) }
    }
}

private enum WidgetChartRange: String, AppEnum {
    case sevenDays
    case fourteenDays
    case thirtyDays
    case ninetyDays

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Chart range")
    static var caseDisplayRepresentations: [WidgetChartRange: DisplayRepresentation] = [
        .sevenDays: "7 days",
        .fourteenDays: "14 days",
        .thirtyDays: "30 days",
        .ninetyDays: "90 days"
    ]

    var days: Int {
        switch self {
        case .sevenDays: 7
        case .fourteenDays: 14
        case .thirtyDays: 30
        case .ninetyDays: 90
        }
    }

    var shortTitle: String { "\(days)d" }
}

private struct LifetwineWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Lifetwine chart"
    static var description = IntentDescription("Choose any number of trackers for your Home Screen chart.")

    @Parameter(title: "Trackers")
    var trackers: [WidgetTrackerEntity]?

    @Parameter(title: "Date range", default: .thirtyDays)
    var range: WidgetChartRange
}

private struct LifetwineWidgetEntry: TimelineEntry {
    let date: Date
    let range: WidgetChartRange
    let trackers: [WidgetChartTracker]
}

private struct LifetwineWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LifetwineWidgetEntry {
        LifetwineWidgetEntry(
            date: .now,
            range: .thirtyDays,
            trackers: [
                WidgetChartTracker(id: "sleep", name: "Sleep", colorHex: "5B68D8", isPinned: true, points: samplePoints(offset: 0)),
                WidgetChartTracker(id: "energy", name: "Energy", colorHex: "58B89C", isPinned: true, points: samplePoints(offset: 1))
            ]
        )
    }

    func snapshot(for configuration: LifetwineWidgetIntent, in context: Context) async -> LifetwineWidgetEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: LifetwineWidgetIntent, in context: Context) async -> Timeline<LifetwineWidgetEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .after(Date.now.addingTimeInterval(60 * 60)))
    }

    private func entry(for configuration: LifetwineWidgetIntent) -> LifetwineWidgetEntry {
        let snapshot = WidgetChartSnapshot.current
        let selectedIDs = Set((configuration.trackers ?? []).map(\.id))
        let chosen: [WidgetChartTracker]
        if selectedIDs.isEmpty {
            let pinned = snapshot.trackers.filter(\.isPinned)
            chosen = Array((pinned.isEmpty ? snapshot.trackers : pinned).prefix(4))
        } else {
            chosen = snapshot.trackers.filter { selectedIDs.contains($0.id) }
        }

        let start = Calendar.current.date(
            byAdding: .day,
            value: -(configuration.range.days - 1),
            to: Calendar.current.startOfDay(for: .now)
        ) ?? .distantPast
        let ranged = chosen.map { tracker in
            let points = tracker.points.filter { $0.date >= start }
            let values = points.map(\.normalizedValue)
            let minimum = values.min() ?? 0
            let maximum = values.max() ?? minimum
            let spread = maximum - minimum
            return WidgetChartTracker(
                id: tracker.id,
                name: tracker.name,
                colorHex: tracker.colorHex,
                isPinned: tracker.isPinned,
                points: points.map {
                    WidgetChartPoint(
                        date: $0.date,
                        normalizedValue: spread > 0.000_001 ? ($0.normalizedValue - minimum) / spread : 0.5
                    )
                }
            )
        }
        return LifetwineWidgetEntry(date: .now, range: configuration.range, trackers: ranged)
    }

    private func samplePoints(offset: Int) -> [WidgetChartPoint] {
        (0..<7).map { day in
            WidgetChartPoint(
                date: Calendar.current.date(byAdding: .day, value: day - 6, to: .now) ?? .now,
                normalizedValue: Double((day + offset) % 5 + 1) / 6
            )
        }
    }
}

private struct LifetwineWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LifetwineWidgetEntry

    private var visibleTrackers: [WidgetChartTracker] {
        switch family {
        case .systemSmall: Array(entry.trackers.prefix(1))
        case .systemMedium: Array(entry.trackers.prefix(3))
        default: Array(entry.trackers.prefix(6))
        }
    }

    private var hasData: Bool { visibleTrackers.contains { !$0.points.isEmpty } }
    private var colorDomain: [String] { visibleTrackers.map(\.name) }
    private var colorRange: [Color] { visibleTrackers.map { Color(widgetHex: $0.colorHex) } }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Link(destination: URL(string: "lifetwine://log")!) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .widgetLabel("Quick Log")
            }

        case .accessoryRectangular:
            Link(destination: URL(string: "lifetwine://log")!) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Lifetwine").fontWeight(.bold)
                        Text("Log anything")
                    }
                }
            }

        default:
            chartWidget
                .widgetURL(URL(string: "lifetwine://patterns"))
        }
    }

    private var chartWidget: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 5 : 9) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Lifetwine").font(.headline)
                    Text(entry.range.shortTitle + " relative chart")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Link(destination: URL(string: "lifetwine://log")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color(widgetHex: "5B68D8"))
                }
            }

            if hasData {
                Chart {
                    ForEach(visibleTrackers) { tracker in
                        ForEach(tracker.points) { point in
                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Relative value", point.normalizedValue),
                                series: .value("Tracker", tracker.name)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(by: .value("Tracker", tracker.name))
                        }
                    }
                }
                .chartForegroundStyleScale(domain: colorDomain, range: colorRange)
                .chartYScale(domain: 0...1)
                .chartLegend(.hidden)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)

                if family != .systemSmall {
                    HStack(spacing: 10) {
                        ForEach(visibleTrackers.prefix(family == .systemLarge ? 6 : 3)) { tracker in
                            HStack(spacing: 4) {
                                Circle().fill(Color(widgetHex: tracker.colorHex)).frame(width: 6, height: 6)
                                Text(tracker.name).lineLimit(1)
                            }
                            .font(.caption2.weight(.semibold))
                        }
                    }
                } else if let tracker = visibleTrackers.first {
                    Text(tracker.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(widgetHex: tracker.colorHex))
                }
            } else {
                Spacer()
                Label("Open Lifetwine to prepare your chart", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

@main
struct LifetwineWidget: Widget {
    let kind = "LifetwineQuickLogWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: LifetwineWidgetIntent.self, provider: LifetwineWidgetProvider()) { entry in
            LifetwineWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(widgetHex: "EEF1FF"), Color(widgetHex: "F1E8FA")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Custom Lifetwine chart")
        .description("Choose your trackers and date range, with one-tap logging beside the chart.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

private extension Color {
    init(widgetHex: String) {
        let clean = widgetHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
