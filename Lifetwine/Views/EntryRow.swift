import SwiftUI

struct EntryRow: View {
    let entry: MetricEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.metric?.symbol ?? "circle")
                .font(.subheadline)
                .foregroundStyle(Color(hex: entry.metric?.colorHex ?? "5B68D8"))
                .frame(width: 38, height: 38)
                .background(Color(hex: entry.metric?.colorHex ?? "5B68D8").opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.metric?.name ?? "Archived tracker")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifetwineTheme.ink)
                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if entry.isSample == true {
                    Text("SAMPLE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(LifetwineTheme.indigo)
                }
            }
            Spacer()
            Text(entry.formattedValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifetwineTheme.secondaryInk)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

