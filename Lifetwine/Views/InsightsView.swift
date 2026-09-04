import SwiftData
import SwiftUI

struct InsightsView: View {
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
                    .presentationDetents([.medium, .large])
            }
        }
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
                    Text("Log on \(report.daysUntilFirstInsight) more day\(report.daysUntilFirstInsight == 1 ? "" : "s") to unlock an early pattern")
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
                    Text(report.bestMatchedDays < CorrelationEngine.minimumPairs ? "Seven matched days is enough to begin." : "Keep logging — variation helps patterns emerge.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                tip("Log outcomes like mood or energy once a day", icon: "face.smiling")
                tip("Log influences when they happen", icon: "clock.arrow.circlepath")
                tip("Consistency matters more than logging everything", icon: "checkmark.circle")
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
            Text("Lifetwine checks same-day patterns and delays of one or two days. It reduces the influence of unusual values and filters likely coincidences. Patterns are clues, not proof that one thing caused another.")
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: finding.isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(finding.isPositive ? LifetwineTheme.mint : LifetwineTheme.coral)

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
}

