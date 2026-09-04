import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MetricEntry.timestamp, order: .reverse) private var entries: [MetricEntry]
    @State private var searchText = ""

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
                                    EntryRow(entry: entry)
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.white)
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
        }
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

