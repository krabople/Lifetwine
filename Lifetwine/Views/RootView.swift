import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(selectedTab: $selectedTab)
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
        }
    }
}

