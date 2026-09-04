import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var showingGlobalLogger = false

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
            openLoggerIfRequested()
        }
        .onOpenURL { url in
            guard url.scheme == "lifetwine" else { return }
            if url.host == "log" {
                selectedTab = 0
                showingGlobalLogger = true
            } else if url.host == "journal" {
                selectedTab = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openLifetwineLogger)) { _ in
            selectedTab = 0
            showingGlobalLogger = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { openLoggerIfRequested() }
        }
    }

    private func openLoggerIfRequested() {
        guard QuickAccessRequest.consume() else { return }
        selectedTab = 0
        showingGlobalLogger = true
    }
}

