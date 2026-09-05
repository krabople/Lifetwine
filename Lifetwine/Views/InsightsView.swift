import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MetricDefinition.sortOrder) private var metrics: [MetricDefinition]
    @Query(sort: \MetricEntry.timestamp) private var entries: [MetricEntry]
    @State private var report = InsightReport(findings: [], loggedDays: 0, bestMatchedDays: 0, loggedValues: 0, correlatedMetricCount: 0)
    @State private var selectedFinding: InsightFinding?

    var body: some View {
        NavigationStack {
            ZStack {
                LifetwineTheme.canvas.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        insightHeader

                        if sampleEntryCount > 0 {
                            sampleDataCard
                        }

                        chartExplorerCard

                        if report.findings.isEmpty {
                            learningCard
                        } else {
                            Text("What Lifetwine noticed")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(LifetwineTheme.ink)
                                .padding(.horizontal, 4)

                            ForEach(report.findings) { finding in
                                Button {
                                    selectedFinding = finding
                                } label: {
                                    FindingCard(finding: finding)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        methodologyCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Patterns")
            .navigationBarTitleDisplayMode(.large)
            .task(id: entries.count) { refreshReport() }
            .sheet(item: $selectedFinding) { finding in
                InsightDetailView(finding: finding)
                    .presentationDetents([.large])
            }
        }
    }

    private var sampleEntryCount: Int { entries.filter { $0.isSample == true }.count }

    private var sampleDataCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(LifetwineTheme.indigo)
                .frame(width: 34, height: 34)
                .background(LifetwineTheme.indigo.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("Showing sample patterns")
                    .font(.subheadline.weight(.bold))
                Text("These results include \(sampleEntryCount) clearly marked demo logs from the previous three weeks, so you can explore this screen immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Remove") {
                SampleDataLibrary.remove(in: modelContext)
                refreshReport()
            }
            .font(.caption.weight(.bold))
        }
        .padding(14)
        .lifetwineCard()
    }

    private var insightHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(report.findings.isEmpty ? "Learning your rhythm" : "Your life, connected")
                        .font(.title2.weight(.bold))
                    Text("Built from \(report.loggedValues) logs across \(report.loggedDays) day\(report.loggedDays == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 29))
                    .frame(width: 58, height: 58)
                    .background(.white.opacity(0.15), in: Circle())
            }

            if report.bestMatchedDays < CorrelationEngine.minimumPairs {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: min(1, Double(report.bestMatchedDays) / Double(CorrelationEngine.minimumPairs)))
                        .tint(.white)
                    Text("Log both sides on \(report.daysUntilFirstInsight) more day\(report.daysUntilFirstInsight == 1 ? "" : "s") to unlock your first comparison")
                        .font(.caption.weight(.semibold))
                }
            } else {
                Label("\(report.correlatedMetricCount) trackers compared, including delayed effects", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "253357"), LifetwineTheme.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var chartExplorerCard: some View {
        NavigationLink {
            ChartExplorerView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2)
                    .foregroundStyle(LifetwineTheme.indigo)
                    .frame(width: 48, height: 48)
                    .background(LifetwineTheme.indigo.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Explore your own chart")
                        .font(.headline)
                        .foregroundStyle(LifetwineTheme.ink)
                    Text("Overlay any number of trackers and date ranges.")
                        .font(.subheadline)
                        .foregroundStyle(LifetwineTheme.secondaryInk)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .lifetwineCard()
        }
        .buttonStyle(.plain)
    }

    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(LifetwineTheme.mint)
                    .frame(width: 42, height: 42)
                    .background(LifetwineTheme.mint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.bestMatchedDays < CorrelationEngine.minimumPairs ? "A little data goes a long way" : "No dependable pattern yet")
                        .font(.headline)
                    Text(report.bestMatchedDays < CorrelationEngine.minimumPairs ? "A matched day means you logged two comparable trackers on the same day. Lifetwine waits for at least seven before showing a tentative result." : "Keep logging — variation helps patterns emerge.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                tip("Log outcomes like mood or energy once a day", icon: "face.smiling")
                tip("Log influences when they happen", icon: "clock.arrow.circlepath")
                tip("Consistency matters more than logging everything", icon: "checkmark.circle")
                tip("You can edit dates, times and values later in Journal", icon: "pencil.circle")
            }
        }
        .padding(18)
        .lifetwineCard()
    }

    private func tip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(LifetwineTheme.secondaryInk)
    }

    private var methodologyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Careful by design", systemImage: "shield.lefthalf.filled")
                .font(.headline)
                .foregroundStyle(LifetwineTheme.ink)
            Text("Lifetwine compares structured values—ratings, amounts, doses, choices, events, durations and times—on the same day and after delays of one or two days. Free-text notes stay searchable but are never treated as numerical evidence. It reduces the influence of unusual values and filters likely coincidences. Patterns are clues, not proof that one thing caused another.")
                .font(.footnote)
                .foregroundStyle(LifetwineTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .lifetwineCard()
    }

    private func refreshReport() {
        let metricSnapshots = metrics.filter { !$0.isArchived }.map(MetricSnapshot.init)
        let entrySnapshots = entries.compactMap(EntrySnapshot.init)
        report = CorrelationEngine.analyze(metrics: metricSnapshots, entries: entrySnapshots)
    }
}

private struct FindingCard: View {
    let finding: InsightFinding

    private var color: Color { finding.isPositive ? LifetwineTheme.mint : LifetwineTheme.coral }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label(finding.strengthWord, systemImage: "sparkle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.11), in: Capsule())
                Spacer()
                Text(finding.lagDays == 0 ? "Same day" : "+\(finding.lagDays) day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(finding.headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LifetwineTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Image(systemName: finding.isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.headline)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 5) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(color.opacity(0.12))
                            Capsule().fill(color).frame(width: proxy.size.width * finding.evidenceScore)
                        }
                    }
                    .frame(height: 6)
                    Text(finding.evidenceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .lifetwineCard()
    }
}

private struct InsightDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let finding: InsightFinding

    private var accent: Color { finding.isPositive ? LifetwineTheme.mint : LifetwineTheme.coral }

    private var regression: [RegressionPoint] {
        guard finding.points.count > 1 else { return [] }
        let xValues = finding.points.map(\.sourceValue)
        let yValues = finding.points.map(\.outcomeValue)
        let meanX = xValues.reduce(0, +) / Double(xValues.count)
        let meanY = yValues.reduce(0, +) / Double(yValues.count)
        let denominator = xValues.map { pow($0 - meanX, 2) }.reduce(0, +)
        guard denominator > 0.000_001, let minimum = xValues.min(), let maximum = xValues.max() else { return [] }
        let slope = zip(xValues, yValues).map { ($0 - meanX) * ($1 - meanY) }.reduce(0, +) / denominator
        let intercept = meanY - slope * meanX
        return [
            RegressionPoint(source: minimum, outcome: intercept + slope * minimum),
            RegressionPoint(source: maximum, outcome: intercept + slope * maximum)
        ]
    }

    private var timeline: [TimelinePoint] {
        let sourceValues = finding.points.map(\.sourceValue)
        let outcomeValues = finding.points.map(\.outcomeValue)
        return finding.points.flatMap { point in
            [
                TimelinePoint(
                    date: point.outcomeDate,
                    series: finding.sourceName,
                    value: normalized(point.sourceValue, within: sourceValues)
                ),
                TimelinePoint(
                    date: point.outcomeDate,
                    series: finding.outcomeName,
                    value: normalized(point.outcomeValue, within: outcomeValues)
                )
            ]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: finding.isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(accent)

                    Text(finding.headline)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(LifetwineTheme.ink)

                    VStack(alignment: .leading, spacing: 12) {
                        detailRow("Matched days", value: "\(finding.sampleCount)")
                        detailRow("Timing", value: finding.lagPhrase.capitalized)
                        detailRow("Pattern strength", value: finding.strengthWord)
                        detailRow("Evidence score", value: "\(Int((finding.evidenceScore * 100).rounded()))%")
                    }
                    .padding(18)
                    .lifetwineCard()

                    chartSection(
                        title: "The correlation",
                        subtitle: "Each dot is one matched pair of days. The line shows the overall direction Lifetwine detected."
                    ) {
                        Chart {
                            ForEach(finding.points) { point in
                                PointMark(
                                    x: .value(finding.sourceName, point.sourceValue),
                                    y: .value(finding.outcomeName, point.outcomeValue)
                                )
                                .foregroundStyle(accent.opacity(0.78))
                                .symbolSize(52)
                            }
                            ForEach(regression) { point in
                                LineMark(
                                    x: .value(finding.sourceName, point.source),
                                    y: .value(finding.outcomeName, point.outcome),
                                    series: .value("Trend", "Trend")
                                )
                                .foregroundStyle(accent)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                            }
                        }
                        .chartXAxisLabel(finding.sourceName)
                        .chartYAxisLabel(finding.outcomeName)
                        .frame(height: 250)
                    }

                    chartSection(
                        title: "How it changed over time",
                        subtitle: finding.lagDays == 0
                            ? "Both lines are aligned on the same day and scaled to their own low-to-high range."
                            : "The \(finding.sourceName.lowercased()) line is shifted by \(finding.lagDays) day\(finding.lagDays == 1 ? "" : "s") so each point lines up with the outcome it was compared with."
                    ) {
                        Chart(timeline) { point in
                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Relative value", point.value),
                                series: .value("Tracker", point.series)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(by: .value("Tracker", point.series))
                            PointMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Relative value", point.value)
                            )
                            .symbolSize(18)
                            .foregroundStyle(by: .value("Tracker", point.series))
                        }
                        .chartForegroundStyleScale(
                            domain: [finding.sourceName, finding.outcomeName],
                            range: [LifetwineTheme.indigo, accent]
                        )
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) {
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            }
                        }
                        .chartYScale(domain: 0...1)
                        .frame(height: 250)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Raw matched data")
                            .font(.headline)
                        Text("These are the exact daily values used for this result—nothing hidden or estimated.")
                            .font(.subheadline)
                            .foregroundStyle(LifetwineTheme.secondaryInk)

                        HStack {
                            Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                            Text(finding.sourceName).frame(maxWidth: .infinity, alignment: .trailing)
                            Text(finding.outcomeName).frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                        Divider()

                        ForEach(finding.points.sorted { $0.sourceDate > $1.sourceDate }) { point in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(point.sourceDate.formatted(.dateTime.day().month(.abbreviated)))
                                    if finding.lagDays > 0 {
                                        Text("Outcome \(point.outcomeDate.formatted(.dateTime.day().month(.abbreviated)))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(format(point.sourceValue, kind: finding.sourceKind, unit: finding.sourceUnit))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(format(point.outcomeValue, kind: finding.outcomeKind, unit: finding.outcomeUnit))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .font(.caption)
                            if point.id != finding.points.first?.id { Divider() }
                        }
                    }
                    .padding(18)
                    .lifetwineCard()

                    Text("What this means")
                        .font(.headline)
                    Text("This relationship appeared repeatedly in the days where you logged both items. It may be worth watching or trying as a small personal experiment. Other untracked factors could still explain it.")
                        .font(.body)
                        .foregroundStyle(LifetwineTheme.secondaryInk)
                }
                .padding(20)
            }
            .background(LifetwineTheme.canvas)
            .navigationTitle("Pattern detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func normalized(_ value: Double, within values: [Double]) -> Double {
        guard let minimum = values.min(), let maximum = values.max(), maximum - minimum > 0.000_001 else { return 0.5 }
        return (value - minimum) / (maximum - minimum)
    }

    private func format(_ value: Double, kind: MetricKind, unit: String) -> String {
        if kind == .time {
            let minutes = max(0, Int(value.rounded()))
            return String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
        }
        if kind == .yesNo || kind == .event { return value >= 0.5 ? "Yes" : "No" }
        let number = value.formatted(.number.precision(.fractionLength(0...2)))
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    @ViewBuilder
    private func chartSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(LifetwineTheme.secondaryInk)
            content()
        }
        .padding(18)
        .lifetwineCard()
    }
}

private struct RegressionPoint: Identifiable {
    let source: Double
    let outcome: Double
    var id: Double { source }
}

private struct TimelinePoint: Identifiable {
    let date: Date
    let series: String
    let value: Double
    var id: String { "\(series)-\(date.timeIntervalSinceReferenceDate)" }
}
