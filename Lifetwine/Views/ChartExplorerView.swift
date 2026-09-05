import Charts
import SwiftData
import SwiftUI

private enum ExplorerRange: String, CaseIterable, Identifiable {
    case fourteen = "14 days"
    case thirty = "30 days"
    case ninety = "90 days"
    case all = "All time"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .fourteen: 14
        case .thirty: 30
        case .ninety: 90
        case .all: nil
        }
    }
}

struct ChartExplorerView: View {
    @Query(sort: \MetricDefinition.sortOrder) private var metrics: [MetricDefinition]
    @Query(sort: \MetricEntry.timestamp) private var entries: [MetricEntry]
    @State private var selectedIDs: Set<UUID> = []
    @State private var range: ExplorerRange = .thirty
    @State private var normalized = true
    @State private var searchText = ""
    @State private var choseDefaults = false

    private var availableMetrics: [MetricDefinition] {
        metrics.filter {
            !$0.isArchived && $0.supportsCorrelation &&
            (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var selectedMetrics: [MetricDefinition] {
        metrics.filter { selectedIDs.contains($0.id) }
    }

    private var points: [TrackerChartPoint] {
        ChartDataBuilder.makePoints(
            metrics: metrics,
            entries: entries,
            selectedIDs: selectedIDs,
            days: range.days
        )
    }

    private var seriesNames: [String] { selectedMetrics.map(\.name) }
    private var seriesColors: [Color] { selectedMetrics.map { Color(hex: $0.colorHex) } }

    var body: some View {
        ZStack {
            LifetwineTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    introCard
                    chartCard
                    trackerPicker
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Chart explorer")
        .navigationBarTitleDisplayMode(.inline)
        .task { chooseDefaultsIfNeeded() }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Put anything side by side", systemImage: "chart.xyaxis.line")
                .font(.headline)
            Text("Choose as many structured trackers as you like. Relative view puts every tracker on the same low-to-high scale, so very different measurements remain easy to compare.")
                .font(.subheadline)
                .foregroundStyle(LifetwineTheme.secondaryInk)
        }
        .padding(16)
        .lifetwineCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Menu {
                    Picker("Date range", selection: $range) {
                        ForEach(ExplorerRange.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label(range.rawValue, systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                Toggle("Relative", isOn: $normalized)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize()
            }

            if selectedIDs.isEmpty {
                ContentUnavailableView(
                    "Choose trackers below",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("There is no selection limit.")
                )
                .frame(height: 260)
            } else if points.isEmpty {
                ContentUnavailableView(
                    "No values in this period",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Try a longer date range or choose another tracker.")
                )
                .frame(height: 260)
            } else {
                Text(normalized ? "Relative position within each tracker's own range" : "Original logged values")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Value", normalized ? point.normalizedValue : point.value),
                        series: .value("Tracker", point.metricName)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Tracker", point.metricName))

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Value", normalized ? point.normalizedValue : point.value)
                    )
                    .symbolSize(20)
                    .foregroundStyle(by: .value("Tracker", point.metricName))
                }
                .chartForegroundStyleScale(domain: seriesNames, range: seriesColors)
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 290)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(selectedMetrics) { metric in
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: metric.colorHex)).frame(width: 8, height: 8)
                            Text(metric.name)
                                .lineLimit(1)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color(hex: metric.colorHex).opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .lifetwineCard()
    }

    private var trackerPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trackers")
                    .font(.title3.weight(.bold))
                Spacer()
                if !selectedIDs.isEmpty {
                    Button("Clear") { selectedIDs.removeAll() }
                        .font(.subheadline.weight(.semibold))
                }
            }

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find a tracker", text: $searchText)
            }
            .padding(11)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            ForEach(availableMetrics) { metric in
                Button {
                    if selectedIDs.contains(metric.id) {
                        selectedIDs.remove(metric.id)
                    } else {
                        selectedIDs.insert(metric.id)
                    }
                    Haptics.selected()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: metric.symbol)
                            .foregroundStyle(Color(hex: metric.colorHex))
                            .frame(width: 34, height: 34)
                            .background(Color(hex: metric.colorHex).opacity(0.1), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LifetwineTheme.ink)
                            Text(metric.kind.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selectedIDs.contains(metric.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectedIDs.contains(metric.id) ? LifetwineTheme.indigo : Color.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if metric.id != availableMetrics.last?.id { Divider().padding(.leading, 46) }
            }
        }
        .padding(16)
        .lifetwineCard()
    }

    private func chooseDefaultsIfNeeded() {
        guard !choseDefaults else { return }
        choseDefaults = true
        let metricsWithData = metrics.filter { metric in
            !metric.isArchived && metric.supportsCorrelation && entries.contains { $0.metric?.id == metric.id }
        }
        let preferred = metricsWithData.filter(\.isPinned)
        selectedIDs = Set((preferred.isEmpty ? metricsWithData : preferred).prefix(3).map(\.id))
    }
}
