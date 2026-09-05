import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MetricDefinition.sortOrder) private var metrics: [MetricDefinition]
    @Query(sort: \MetricEntry.timestamp) private var entries: [MetricEntry]
    @State private var selectedTab = 0
    @State private var showingGlobalLogger = false
    @State private var metricToLog: MetricDefinition?

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(selectedTab: $selectedTab, showingGlobalLogger: $showingGlobalLogger)
                .tabItem { Label("Today", systemImage: "sparkles") }
                .tag(0)

            HistoryView()
                .tabItem { Label("Journal", systemImage: "calendar") }
                .tag(1)

            InsightsView()
                .tabItem { Label("Patterns", systemImage: "point.3.connected.trianglepath.dotted") }
                .tag(2)

            TrackersView()
                .tabItem { Label("Trackers", systemImage: "square.grid.2x2") }
                .tag(3)
        }
        .tint(LifetwineTheme.indigo)
        .task {
            StarterLibrary.installIfNeeded(in: modelContext)
            SampleDataLibrary.installIfNeeded(in: modelContext)
            let savedMetrics = (try? modelContext.fetch(FetchDescriptor<MetricDefinition>())) ?? []
            await ReminderScheduler.rebuild(for: savedMetrics)
            openLoggerIfRequested()
            openMetricIfRequested()
        }
        .task(id: widgetSnapshotSignature) {
            WidgetSnapshotStore.refresh(metrics: metrics, entries: entries)
        }
        .onOpenURL { url in
            guard url.scheme == "lifetwine" else { return }
            if url.host == "log" {
                selectedTab = 0
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let value = components.queryItems?.first(where: { $0.name == "metricID" })?.value,
                   let metricID = UUID(uuidString: value) {
                    openMetric(metricID)
                } else {
                    showingGlobalLogger = true
                }
            } else if url.host == "journal" {
                selectedTab = 1
            } else if url.host == "patterns" {
                selectedTab = 2
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openLifetwineLogger)) { _ in
            selectedTab = 0
            showingGlobalLogger = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openLifetwineMetric)) { notification in
            guard let value = notification.object as? String, let metricID = UUID(uuidString: value) else { return }
            openMetric(metricID)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                openLoggerIfRequested()
                openMetricIfRequested()
            }
        }
        .sheet(item: $metricToLog) { metric in
            EntryEditorView(metric: metric)
        }
    }

    private func openLoggerIfRequested() {
        guard QuickAccessRequest.consume() else { return }
        selectedTab = 0
        showingGlobalLogger = true
    }

    private func openMetricIfRequested() {
        guard let metricID = QuickAccessRequest.consumeMetricID() else { return }
        openMetric(metricID)
    }

    private func openMetric(_ metricID: UUID) {
        guard let metric = metrics.first(where: { $0.id == metricID && !$0.isArchived }) else { return }
        selectedTab = 0
        showingGlobalLogger = false
        metricToLog = metric
    }

    private var widgetSnapshotSignature: String {
        let metricPart = metrics.map {
            "\($0.id.uuidString):\($0.name):\($0.colorHex):\($0.isPinned):\($0.isArchived):\($0.aggregationRaw)"
        }.joined(separator: "|")
        let latestChange = entries.map { ($0.updatedAt ?? $0.createdAt).timeIntervalSinceReferenceDate }.max() ?? 0
        return "\(metricPart)#\(entries.count)#\(latestChange)"
    }
}
