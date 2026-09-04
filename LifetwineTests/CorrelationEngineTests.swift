import XCTest
@testable import Lifetwine

final class CorrelationEngineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    func testFindsStrongPositiveSameDayPattern() {
        let sleepID = UUID()
        let energyID = UUID()
        let metrics = [
            MetricSnapshot(id: sleepID, name: "Sleep", kind: .duration, unit: "hours", role: .influence),
            MetricSnapshot(id: energyID, name: "Energy", kind: .scale, role: .outcome)
        ]
        var entries: [EntrySnapshot] = []
        for day in 0..<18 {
            let date = calendar.date(byAdding: .day, value: day, to: start)!
            let sleep = Double((day * 7) % 6) + 4
            entries.append(EntrySnapshot(metricID: sleepID, timestamp: date, numericValue: sleep))
            entries.append(EntrySnapshot(metricID: energyID, timestamp: date, numericValue: sleep * 0.7 + 0.5))
        }

        let report = CorrelationEngine.analyze(metrics: metrics, entries: entries, calendar: calendar)

        XCTAssertEqual(report.findings.first?.sourceName, "Sleep")
        XCTAssertEqual(report.findings.first?.outcomeName, "Energy")
        XCTAssertEqual(report.findings.first?.lagDays, 0)
        XCTAssertGreaterThan(report.findings.first?.effect ?? 0, 0.9)
    }

    func testFindsOneDayDelayedPattern() {
        let lateMealID = UUID()
        let energyID = UUID()
        let metrics = [
            MetricSnapshot(id: lateMealID, name: "Meal time", kind: .time, role: .influence, aggregation: .latest),
            MetricSnapshot(id: energyID, name: "Energy", kind: .scale, role: .outcome)
        ]
        let values = [2.0, 9, 1, 7, 4, 10, 3, 8, 1, 6, 9, 2, 7, 3, 10, 5, 8, 4, 9, 1]
        var entries: [EntrySnapshot] = []
        for day in values.indices {
            let sourceDate = calendar.date(byAdding: .day, value: day, to: start)!
            let outcomeDate = calendar.date(byAdding: .day, value: day + 1, to: start)!
            entries.append(EntrySnapshot(metricID: lateMealID, timestamp: sourceDate, numericValue: values[day]))
            entries.append(EntrySnapshot(metricID: energyID, timestamp: outcomeDate, numericValue: 12 - values[day]))
        }

        let report = CorrelationEngine.analyze(metrics: metrics, entries: entries, calendar: calendar)
        let finding = report.findings.first { $0.sourceName == "Meal time" }

        XCTAssertEqual(finding?.lagDays, 1)
        XCTAssertLessThan(finding?.effect ?? 0, -0.9)
    }

    func testDoesNotInventPatternFromConstantValues() {
        let sourceID = UUID()
        let outcomeID = UUID()
        let metrics = [
            MetricSnapshot(id: sourceID, name: "Water", kind: .number, role: .influence, aggregation: .total),
            MetricSnapshot(id: outcomeID, name: "Mood", kind: .scale, role: .outcome)
        ]
        var entries: [EntrySnapshot] = []
        for day in 0..<20 {
            let date = calendar.date(byAdding: .day, value: day, to: start)!
            entries.append(EntrySnapshot(metricID: sourceID, timestamp: date, numericValue: 250))
            entries.append(EntrySnapshot(metricID: outcomeID, timestamp: date, numericValue: Double(day % 5)))
        }

        let report = CorrelationEngine.analyze(metrics: metrics, entries: entries, calendar: calendar)

        XCTAssertTrue(report.findings.isEmpty)
    }

    func testRequiresSevenMatchedDays() {
        let sourceID = UUID()
        let outcomeID = UUID()
        let metrics = [
            MetricSnapshot(id: sourceID, name: "Exercise", kind: .duration, role: .influence),
            MetricSnapshot(id: outcomeID, name: "Mood", kind: .scale, role: .outcome)
        ]
        var entries: [EntrySnapshot] = []
        for day in 0..<6 {
            let date = calendar.date(byAdding: .day, value: day, to: start)!
            entries.append(EntrySnapshot(metricID: sourceID, timestamp: date, numericValue: Double(day)))
            entries.append(EntrySnapshot(metricID: outcomeID, timestamp: date, numericValue: Double(day)))
        }

        let report = CorrelationEngine.analyze(metrics: metrics, entries: entries, calendar: calendar)

        XCTAssertTrue(report.findings.isEmpty)
        XCTAssertEqual(report.daysUntilFirstInsight, 1)
    }
}

