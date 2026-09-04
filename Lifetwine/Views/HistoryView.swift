import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MetricEntry.timestamp, order: .reverse) private var entries: [MetricEntry]
    @State private var searchText = ""
    @State private var editingEntry: MetricEntry?
    @State private var showingLogger = false

    private var filteredEntries: [MetricEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            ($0.metric?.name.localizedCaseInsensitiveContains(searchText) ?? false) ||
            $0.textValue.localizedCaseInsensitiveContains(searchText) ||
            $0.note.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedEntries: [(Date, [MetricEntry])] {
        let groups = Dictionary(grouping: filteredEntries) { Calendar.current.startOfDay(for: $0.timestamp) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Your journal starts here",
                        systemImage: "calendar.badge.plus",
                        description: Text("Anything you log appears here in a simple timeline.")
                    )
                } else if filteredEntries.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(groupedEntries, id: \.0) { day, dayEntries in
                            Section {
                                ForEach(dayEntries) { entry in
                                    Button { editingEntry = entry } label: {
                                        EntryRow(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.white)
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button {
                                            editingEntry = entry
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(LifetwineTheme.indigo)

                                        Button {
                                            duplicate(entry)
                                        } label: {
                                            Label("Repeat", systemImage: "plus.square.on.square")
                                        }
                                        .tint(LifetwineTheme.mint)
                                    }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                modelContext.delete(entry)
                                                try? modelContext.save()
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                Text(dayLabel(day))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(LifetwineTheme.ink)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(LifetwineTheme.canvas)
                }
            }
            .navigationTitle("Journal")
            .searchable(text: $searchText, prompt: "Search what you logged")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingLogger = true } label: {
                        Label("Log anything", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editingEntry) { entry in
                if let metric = entry.metric {
                    EntryEditorView(metric: metric, entry: entry)
                }
            }
            .sheet(isPresented: $showingLogger) {
                UniversalLoggerView()
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func duplicate(_ entry: MetricEntry) {
        guard let metric = entry.metric else { return }
        let copy = MetricEntry(
            timestamp: .now,
            numericValue: entry.numericValue,
            textValue: entry.textValue,
            note: entry.note,
            metric: metric
        )
        modelContext.insert(copy)
        metric.lastUsedAt = .now
        try? modelContext.save()
        Haptics.logged()
    }
}

