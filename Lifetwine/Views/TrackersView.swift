import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TrackersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MetricDefinition.sortOrder) private var metrics: [MetricDefinition]
    @Query(sort: \MetricEntry.timestamp) private var entries: [MetricEntry]

    @State private var showingEditor = false
    @State private var editingMetric: MetricDefinition?
    @State private var showingExporter = false
    @State private var exportDocument = CSVExportDocument()
    @State private var showingArchived = false
    @State private var searchText = ""

    private var activeMetrics: [MetricDefinition] {
        metrics.filter {
            !$0.isArchived && (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.kind.title.localizedCaseInsensitiveContains(searchText))
        }
    }
    private var archivedMetrics: [MetricDefinition] { metrics.filter(\.isArchived) }
    private var sampleEntryCount: Int { entries.filter { $0.isSample == true }.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        editingMetric = nil
                        showingEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LifetwineTheme.indigo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create any tracker")
                                    .font(.headline)
                                    .foregroundStyle(LifetwineTheme.ink)
                                Text("Any subject, any format — no limit")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if activeMetrics.isEmpty {
                    ContentUnavailableView(
                        "Make Lifetwine yours",
                        systemImage: "plus.square.dashed",
                        description: Text("Add anything you want to understand.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(activeMetrics) { metric in
                            Button {
                                editingMetric = metric
                                showingEditor = true
                            } label: {
                                trackerRow(metric)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button {
                                    metric.isPinned.toggle()
                                    try? modelContext.save()
                                } label: {
                                    Label(metric.isPinned ? "Unpin" : "Quick log", systemImage: metric.isPinned ? "pin.slash" : "pin")
                                }
                                .tint(LifetwineTheme.indigo)

                                Button {
                                    duplicate(metric)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                .tint(LifetwineTheme.mint)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    metric.isArchived = true
                                    try? modelContext.save()
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                        .onMove(perform: move)
                    } header: {
                        Text("Your trackers (\(activeMetrics.count))")
                    } footer: {
                        Text("Tap to edit. Swipe right to show on Today or duplicate. Drag while editing to reorder.")
                    }
                }

                Section("Privacy & data") {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Private by default")
                            Text("Your entries stay on this iPhone and in your private iCloud backup, if enabled.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill").foregroundStyle(LifetwineTheme.mint)
                    }

                    Button {
                        exportDocument = CSVExportDocument(entries: entries)
                        showingExporter = true
                    } label: {
                        Label("Export all entries", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)

                    if sampleEntryCount > 0 {
                        Label("\(sampleEntryCount) clearly marked sample logs are included so you can explore Patterns.", systemImage: "sparkles")
                            .font(.subheadline)
                            .foregroundStyle(LifetwineTheme.indigo)
                        Button(role: .destructive) {
                            SampleDataLibrary.remove(in: modelContext)
                        } label: {
                            Label("Remove sample history", systemImage: "trash")
                        }
                    } else {
                        Button {
                            SampleDataLibrary.install(in: modelContext)
                        } label: {
                            Label("Add 21 days of sample history", systemImage: "wand.and.stars")
                        }
                    }
                }

                if !archivedMetrics.isEmpty {
                    Section {
                        DisclosureGroup("Archived trackers", isExpanded: $showingArchived) {
                            ForEach(archivedMetrics) { metric in
                                HStack {
                                    trackerRow(metric)
                                    Button("Restore") {
                                        metric.isArchived = false
                                        try? modelContext.save()
                                    }
                                    .font(.caption.weight(.bold))
                                }
                            }
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Lifetwine")
                            .font(.headline)
                        Text("Small moments. Clearer patterns.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(LifetwineTheme.canvas)
            .navigationTitle("Trackers")
            .searchable(text: $searchText, prompt: "Find a tracker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingMetric = nil
                        showingEditor = true
                    } label: {
                        Label("Add tracker", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                MetricEditorView(metric: editingMetric)
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "Lifetwine Export \(Date.now.formatted(.dateTime.year().month().day()))"
            ) { _ in }
        }
    }

    private func duplicate(_ metric: MetricDefinition) {
        let copy = MetricDefinition(
            name: "\(metric.name) copy",
            kind: metric.kind,
            unit: metric.unit,
            symbol: metric.symbol,
            colorHex: metric.colorHex,
            minimumValue: metric.minimumValue,
            maximumValue: metric.maximumValue,
            stepValue: metric.stepValue,
            defaultValue: metric.defaultValue,
            lowLabel: metric.lowLabel,
            highLabel: metric.highLabel,
            choices: metric.choices,
            aggregation: metric.aggregation,
            role: metric.role,
            isPinned: metric.isPinned,
            sortOrder: metrics.count + 1,
            promptText: metric.promptText ?? "",
            quickValues: metric.quickValues,
            positiveLabel: metric.yesLabel,
            negativeLabel: metric.noLabel,
            medications: metric.medications
        )
        modelContext.insert(copy)
        try? modelContext.save()
        editingMetric = copy
        showingEditor = true
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = activeMetrics
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, metric) in reordered.enumerated() { metric.sortOrder = index }
        try? modelContext.save()
    }

    private func trackerRow(_ metric: MetricDefinition) -> some View {
        HStack(spacing: 12) {
            Image(systemName: metric.symbol)
                .foregroundStyle(Color(hex: metric.colorHex))
                .frame(width: 40, height: 40)
                .background(Color(hex: metric.colorHex).opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LifetwineTheme.ink)
                Text(metric.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if metric.isPinned && !metric.isArchived {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(LifetwineTheme.indigo)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

