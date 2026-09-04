import SwiftData
import SwiftUI

struct TodayView: View {
    @Binding var selectedTab: Int
    @Binding var showingGlobalLogger: Bool
    @Query(sort: \MetricDefinition.sortOrder) private var metrics: [MetricDefinition]
    @Query(sort: \MetricEntry.timestamp, order: .reverse) private var entries: [MetricEntry]
    @State private var showingCustomization = false
    @State private var editingEntry: MetricEntry?

    private var pinnedMetrics: [MetricDefinition] {
        metrics.filter { $0.isPinned && !$0.isArchived }
    }

    private var activeMetrics: [MetricDefinition] {
        metrics.filter { !$0.isArchived }
    }

    private var todayEntries: [MetricEntry] {
        entries.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifetwineTheme.canvas.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        header

                        Button {
                            showingGlobalLogger = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Log or create anything")
                                        .font(.headline)
                                    Text("Search every tracker, or make a new one")
                                        .font(.caption)
                                        .foregroundStyle(LifetwineTheme.secondaryInk)
                                }
                                Spacer()
                                Image(systemName: "magnifyingglass")
                            }
                            .foregroundStyle(LifetwineTheme.indigo)
                            .padding(16)
                            .lifetwineCard()
                        }
                        .buttonStyle(.plain)

                        HStack {
                            Text("Quick log")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(LifetwineTheme.ink)
                            Spacer()
                            Button("Customise") { showingCustomization = true }
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 4)

                        if pinnedMetrics.isEmpty {
                            emptyPinnedCard
                        } else {
                            ForEach(pinnedMetrics) { metric in
                                QuickLogCard(metric: metric)
                            }
                        }

                        if !todayEntries.isEmpty {
                            recentSection
                        }

                        Button {
                            selectedTab = 2
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                    .font(.title2)
                                    .foregroundStyle(LifetwineTheme.indigo)
                                    .frame(width: 46, height: 46)
                                    .background(LifetwineTheme.indigo.opacity(0.1), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("See what connects")
                                        .font(.headline)
                                        .foregroundStyle(LifetwineTheme.ink)
                                    Text("Lifetwine looks for patterns as you log.")
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingGlobalLogger) {
                UniversalLoggerView()
            }
            .sheet(isPresented: $showingCustomization) {
                TodayCustomizationView()
            }
            .sheet(item: $editingEntry) { entry in
                if let metric = entry.metric {
                    EntryEditorView(metric: metric, entry: entry)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.largeTitle.weight(.bold))
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                ZStack {
                    Circle().fill(.white.opacity(0.16))
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.title2)
                }
                .frame(width: 48, height: 48)
            }

            HStack(spacing: 8) {
                Image(systemName: todayEntries.isEmpty ? "plus.circle.fill" : "checkmark.circle.fill")
                Text(todayEntries.isEmpty ? "Nothing logged yet — start with one tap" : "\(todayEntries.count) moment\(todayEntries.count == 1 ? "" : "s") captured today")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [LifetwineTheme.indigo, Color(hex: "7C63C8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.top, 8)
    }

    private var emptyPinnedCard: some View {
        Button {
            showingCustomization = true
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "pin")
                    .font(.title2)
                Text("Pin your everyday trackers here")
                    .font(.headline)
                Text("Choose Trackers, then switch on “Show in Quick log”.")
                    .font(.subheadline)
                    .foregroundStyle(LifetwineTheme.secondaryInk)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .lifetwineCard()
        }
        .buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Latest today")
                .font(.title3.weight(.bold))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(todayEntries.prefix(4).enumerated()), id: \.element.id) { index, entry in
                    Button { editingEntry = entry } label: {
                        EntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    if index < min(todayEntries.count, 4) - 1 { Divider().padding(.leading, 58) }
                }
            }
            .padding(.vertical, 5)
            .lifetwineCard()
        }
    }
}

