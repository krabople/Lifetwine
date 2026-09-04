import SwiftData
import SwiftUI

@main
struct LifetwineApp: App {
    @UIApplicationDelegateAdaptor(LifetwineAppDelegate.self) private var appDelegate

    private let container: ModelContainer = {
        let schema = Schema([MetricDefinition.self, MetricEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create Lifetwine's private data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}

