import SwiftUI
import WidgetKit

private struct LifetwineWidgetEntry: TimelineEntry {
    let date: Date
}

private struct LifetwineWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LifetwineWidgetEntry {
        LifetwineWidgetEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (LifetwineWidgetEntry) -> Void) {
        completion(LifetwineWidgetEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LifetwineWidgetEntry>) -> Void) {
        completion(Timeline(entries: [LifetwineWidgetEntry(date: .now)], policy: .never))
    }
}

private struct LifetwineWidgetView: View {
    @Environment(\.widgetFamily) private var family

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

        case .systemMedium:
            HStack(spacing: 12) {
                Link(destination: URL(string: "lifetwine://log")!) {
                    widgetButton("Log anything", subtitle: "Search or create", icon: "plus.circle.fill")
                }
                Link(destination: URL(string: "lifetwine://journal")!) {
                    widgetButton("Journal", subtitle: "Edit or repeat", icon: "calendar")
                }
            }

        default:
            Link(destination: URL(string: "lifetwine://log")!) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                    Spacer()
                    Text("Log anything")
                        .font(.headline)
                    Text("One tap to Lifetwine")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    private func widgetButton(_ title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.title2)
            Spacer()
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

@main
struct LifetwineWidget: Widget {
    let kind = "LifetwineQuickLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LifetwineWidgetProvider()) { _ in
            LifetwineWidgetView()
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.91, green: 0.93, blue: 1), Color(red: 0.93, green: 0.89, blue: 0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Quick Log")
        .description("Jump straight into Lifetwine to record anything.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

