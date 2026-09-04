import SwiftData
import SwiftUI

struct UniversalLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MetricDefinition.sortOrder) private var metrics: [MetricDefinition]
    @State private var searchText = ""
    @State private var showingCreator = false

    private var activeMetrics: [MetricDefinition] {
        let active = metrics.filter { !$0.isArchived }
        let filtered = searchText.isEmpty ? active : active.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.kind.title.localizedCaseInsensitiveContains(searchText) ||
            $0.unit.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted {
            switch ($0.lastUsedAt, $1.lastUsedAt) {
            case let (lhs?, rhs?): lhs > rhs
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): $0.sortOrder < $1.sortOrder
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    createAnythingCard

                    if activeMetrics.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "Create your first tracker" : "Nothing matches",
                            systemImage: searchText.isEmpty ? "plus.square.dashed" : "magnifyingglass",
                            description: Text(searchText.isEmpty ? "Track literally anything, in the format that suits it." : "Create “\(searchText)” as a new tracker instead.")
                        )
                        .padding(.top, 30)
                    } else {
                        ForEach(activeMetrics) { metric in
                            QuickLogCard(metric: metric)
                        }
                    }
                }
                .padding(16)
            }
            .background(LifetwineTheme.canvas)
            .navigationTitle("Log anything")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search all your trackers")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreator = true
                    } label: {
                        Label("New tracker", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreator) {
                MetricEditorView(metric: nil)
            }
        }
    }

    private var createAnythingCard: some View {
        Button {
            showingCreator = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(LifetwineTheme.indigo, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create your own tracker")
                        .font(.headline)
                        .foregroundStyle(LifetwineTheme.ink)
                    Text("Any subject, any format, unlimited trackers")
                        .font(.caption)
                        .foregroundStyle(LifetwineTheme.secondaryInk)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .lifetwineCard()
        }
        .buttonStyle(.plain)
    }
}

struct TodayCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MetricDefinition.sortOrder) private var metrics: [MetricDefinition]
    @State private var showingCreator = false

    private var activeMetrics: [MetricDefinition] { metrics.filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(activeMetrics) { metric in
                        HStack(spacing: 12) {
                            Image(systemName: metric.symbol)
                                .foregroundStyle(Color(hex: metric.colorHex))
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.name).fontWeight(.semibold)
                                Text(metric.kind.title).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Show", isOn: Binding(
                                get: { metric.isPinned },
                                set: { value in
                                    metric.isPinned = value
                                    try? modelContext.save()
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                    .onMove(perform: move)
                } header: {
                    Text("Choose and reorder Today")
                } footer: {
                    Text("Turn off anything you never log, such as Sleep. Its history and pattern data remain safe, and you can turn it back on at any time.")
                }

                Section {
                    Button {
                        showingCreator = true
                    } label: {
                        Label("Create another tracker", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Customise Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showingCreator) {
                MetricEditorView(metric: nil)
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = activeMetrics
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, metric) in reordered.enumerated() { metric.sortOrder = index }
        try? modelContext.save()
        Haptics.selected()
    }
}

