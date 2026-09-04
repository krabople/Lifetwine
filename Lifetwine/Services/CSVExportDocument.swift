import SwiftUI
import UniformTypeIdentifiers

struct CSVExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var content: String

    init(entries: [MetricEntry] = []) {
        let formatter = ISO8601DateFormatter()
        var lines = ["date,tracker,type,value,unit,note,is_sample"]
        for entry in entries {
            let metric = entry.metric
            let rawValue = entry.textValue.isEmpty
                ? entry.numericValue.map { String($0) } ?? ""
                : entry.textValue
            let columns = [
                formatter.string(from: entry.timestamp),
                metric?.name ?? "",
                metric?.kind.title ?? "",
                rawValue,
                entry.valueUnit ?? metric?.unit ?? "",
                entry.note,
                entry.isSample == true ? "true" : "false"
            ]
            lines.append(columns.map(Self.escape).joined(separator: ","))
        }
        content = lines.joined(separator: "\n")
    }

    init(configuration: ReadConfiguration) throws {
        content = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(content.utf8))
    }

    private static func escape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

