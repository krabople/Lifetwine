import Foundation

struct MetricSnapshot: Hashable, Sendable {
    let id: UUID
    let name: String
    let kind: MetricKind
    let unit: String
    let role: MetricRole
    let aggregation: MetricAggregation
    let choices: [String]

    init(
        id: UUID,
        name: String,
        kind: MetricKind,
        unit: String = "",
        role: MetricRole,
        aggregation: MetricAggregation = .average,
        choices: [String] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.unit = unit
        self.role = role
        self.aggregation = aggregation
        self.choices = choices
    }

    init(_ metric: MetricDefinition) {
        id = metric.id
        name = metric.name
        kind = metric.kind
        unit = metric.unit
        role = metric.role
        aggregation = metric.aggregation
        choices = metric.choices
    }
}

struct EntrySnapshot: Hashable, Sendable {
    let metricID: UUID
    let timestamp: Date
    let numericValue: Double?
    let textValue: String

    init?(_ entry: MetricEntry) {
        guard let metricID = entry.metric?.id else { return nil }
        self.metricID = metricID
        timestamp = entry.timestamp
        numericValue = entry.numericValue
        textValue = entry.textValue
    }

    init(metricID: UUID, timestamp: Date, numericValue: Double?, textValue: String = "") {
        self.metricID = metricID
        self.timestamp = timestamp
        self.numericValue = numericValue
        self.textValue = textValue
    }
}

struct InsightReport: Sendable {
    let findings: [InsightFinding]
    let loggedDays: Int
    let bestMatchedDays: Int
    let loggedValues: Int
    let correlatedMetricCount: Int

    var daysUntilFirstInsight: Int { max(0, CorrelationEngine.minimumPairs - bestMatchedDays) }
}

struct InsightPoint: Identifiable, Hashable, Sendable {
    let sourceDate: Date
    let outcomeDate: Date
    let sourceValue: Double
    let outcomeValue: Double

    var id: String {
        "\(sourceDate.timeIntervalSinceReferenceDate)-\(outcomeDate.timeIntervalSinceReferenceDate)"
    }
}

struct InsightFinding: Identifiable, Hashable, Sendable {
    let id: String
    let sourceName: String
    let outcomeName: String
    let sourceKind: MetricKind
    let outcomeKind: MetricKind
    let sourceUnit: String
    let outcomeUnit: String
    let effect: Double
    let lagDays: Int
    let sampleCount: Int
    let evidenceScore: Double
    let adjustedProbability: Double
    let points: [InsightPoint]

    var isPositive: Bool { effect > 0 }

    var strengthWord: String {
        switch abs(effect) {
        case 0.65...: "Strong"
        case 0.45...: "Clear"
        default: "Possible"
        }
    }

    var lagPhrase: String {
        switch lagDays {
        case 0: "on the same day"
        case 1: "the following day"
        default: "\(lagDays) days later"
        }
    }

    var headline: String {
        let outcomeDirection = isPositive ? "higher" : "lower"
        switch sourceKind {
        case .yesNo, .event:
            return "When you logged \(sourceName.lowercased()), \(outcomeName.lowercased()) tended to be \(outcomeDirection) \(lagPhrase)."
        case .time:
            return "Later \(sourceName.lowercased()) tended to come with \(outcomeDirection) \(outcomeName.lowercased()) \(lagPhrase)."
        default:
            let sourceDirection = "Higher \(sourceName.lowercased())"
            return "\(sourceDirection) tended to come with \(outcomeDirection) \(outcomeName.lowercased()) \(lagPhrase)."
        }
    }

    var evidenceText: String {
        "\(sampleCount) matched days • \(Int((evidenceScore * 100).rounded()))% evidence score"
    }
}

enum CorrelationEngine {
    static let minimumPairs = 7

    private struct Series {
        let identity: String
        let metricID: UUID
        let name: String
        let kind: MetricKind
        let unit: String
        let role: MetricRole
        let values: [Date: Double]
    }

    private struct Candidate {
        let source: Series
        let outcome: Series
        let effect: Double
        let lag: Int
        let sampleCount: Int
        let pValue: Double
        let points: [InsightPoint]
        var adjustedProbability: Double = 1
    }

    static func analyze(
        metrics: [MetricSnapshot],
        entries: [EntrySnapshot],
        calendar: Calendar = .current
    ) -> InsightReport {
        // Free text is context, not a defensible numeric signal. Structured events and
        // selections remain eligible; notes are intentionally excluded.
        let eligibleMetrics = metrics.filter { $0.kind != .note }
        let metricMap = Dictionary(uniqueKeysWithValues: eligibleMetrics.map { ($0.id, $0) })
        let usableEntries = entries.filter {
            guard let metric = metricMap[$0.metricID] else { return false }
            return $0.numericValue != nil || (metric.kind == .multiChoice && !$0.textValue.isEmpty)
        }
        let loggedDays = Set(usableEntries.map { calendar.startOfDay(for: $0.timestamp) }).count
        let dailyValues = makeDailyValues(metrics: metricMap, entries: usableEntries, calendar: calendar)
        let series = makeSeries(metrics: eligibleMetrics, dailyValues: dailyValues, entries: usableEntries, calendar: calendar)
        let sources = series.filter { $0.role != .outcome }
        let outcomes = series.filter { $0.role != .influence && $0.kind != .choice }
        let bestMatchedDays = sources.flatMap { source in
            outcomes
                .filter { $0.metricID != source.metricID }
                .map { outcome in Set(source.values.keys).intersection(outcome.values.keys).count }
        }.max() ?? 0

        var bestByPair: [String: Candidate] = [:]
        for source in sources {
            for outcome in outcomes where source.metricID != outcome.metricID {
                if source.role == .both, outcome.role == .both,
                   source.metricID.uuidString > outcome.metricID.uuidString {
                    continue
                }

                for lag in 0...2 {
                    let pairs = matchedPairs(source: source.values, outcome: outcome.values, lag: lag, calendar: calendar)
                    guard pairs.count >= minimumPairs else { continue }
                    let x = pairs.map(\.sourceValue)
                    let y = pairs.map(\.outcomeValue)
                    guard standardDeviation(x) > 0.0001, standardDeviation(y) > 0.0001 else { continue }

                    let pearsonValue = pearson(x, y)
                    let spearmanValue = pearson(ranks(x), ranks(y))
                    let robustEffect = (0.35 * pearsonValue) + (0.65 * spearmanValue)
                    guard robustEffect.isFinite else { continue }

                    let p = approximatePValue(correlation: spearmanValue, sampleCount: pairs.count)
                    let candidate = Candidate(
                        source: source,
                        outcome: outcome,
                        effect: robustEffect,
                        lag: lag,
                        sampleCount: pairs.count,
                        pValue: p,
                        points: pairs.map {
                            InsightPoint(
                                sourceDate: $0.sourceDate,
                                outcomeDate: $0.outcomeDate,
                                sourceValue: $0.sourceValue,
                                outcomeValue: $0.outcomeValue
                            )
                        }
                    )
                    let key = "\(source.identity)|\(outcome.identity)"
                    if let existing = bestByPair[key] {
                        if abs(candidate.effect) > abs(existing.effect) { bestByPair[key] = candidate }
                    } else {
                        bestByPair[key] = candidate
                    }
                }
            }
        }

        var candidates = Array(bestByPair.values)
        applyFalseDiscoveryRate(to: &candidates)

        let findings = candidates
            .filter { abs($0.effect) >= 0.28 && $0.adjustedProbability <= 0.25 }
            .map { candidate in
                let sampleDepth = min(1, Double(candidate.sampleCount - minimumPairs) / 21)
                let evidence = min(0.99, max(0, (1 - candidate.adjustedProbability) * 0.72 + sampleDepth * 0.28))
                return InsightFinding(
                    id: "\(candidate.source.identity)-\(candidate.outcome.identity)-\(candidate.lag)",
                    sourceName: candidate.source.name,
                    outcomeName: candidate.outcome.name,
                    sourceKind: candidate.source.kind,
                    outcomeKind: candidate.outcome.kind,
                    sourceUnit: candidate.source.unit,
                    outcomeUnit: candidate.outcome.unit,
                    effect: candidate.effect,
                    lagDays: candidate.lag,
                    sampleCount: candidate.sampleCount,
                    evidenceScore: evidence,
                    adjustedProbability: candidate.adjustedProbability,
                    points: candidate.points.sorted { $0.sourceDate < $1.sourceDate }
                )
            }
            .sorted {
                let lhs = abs($0.effect) * $0.evidenceScore
                let rhs = abs($1.effect) * $1.evidenceScore
                return lhs > rhs
            }

        return InsightReport(
            findings: findings,
            loggedDays: loggedDays,
            bestMatchedDays: bestMatchedDays,
            loggedValues: usableEntries.count,
            correlatedMetricCount: Set(usableEntries.map(\.metricID)).count
        )
    }

    private static func makeDailyValues(
        metrics: [UUID: MetricSnapshot],
        entries: [EntrySnapshot],
        calendar: Calendar
    ) -> [UUID: [Date: Double]] {
        var buckets: [UUID: [Date: [(Date, Double)]]] = [:]
        for entry in entries {
            guard let value = entry.numericValue else { continue }
            let day = calendar.startOfDay(for: entry.timestamp)
            buckets[entry.metricID, default: [:]][day, default: []].append((entry.timestamp, value))
        }

        var result: [UUID: [Date: Double]] = [:]
        for (metricID, days) in buckets {
            guard let metric = metrics[metricID] else { continue }
            for (day, values) in days {
                let aggregate: Double
                switch metric.aggregation {
                case .average:
                    aggregate = values.map(\.1).reduce(0, +) / Double(values.count)
                case .total:
                    aggregate = values.map(\.1).reduce(0, +)
                case .latest:
                    aggregate = values.max(by: { $0.0 < $1.0 })?.1 ?? values[0].1
                case .count:
                    aggregate = Double(values.count)
                }
                result[metricID, default: [:]][day] = aggregate
            }
        }
        return result
    }

    private static func makeSeries(
        metrics: [MetricSnapshot],
        dailyValues: [UUID: [Date: Double]],
        entries: [EntrySnapshot],
        calendar: Calendar
    ) -> [Series] {
        var result: [Series] = []
        for metric in metrics {
            if metric.kind == .multiChoice, !metric.choices.isEmpty {
                let days = Dictionary(grouping: entries.filter { $0.metricID == metric.id }) {
                    calendar.startOfDay(for: $0.timestamp)
                }
                for (index, choice) in metric.choices.enumerated() {
                    let values = days.mapValues { dayEntries in
                        dayEntries.contains { selectedChoices(in: $0.textValue).contains(choice) } ? 1.0 : 0.0
                    }
                    guard !values.isEmpty else { continue }
                    result.append(Series(
                        identity: "\(metric.id.uuidString):multi:\(index)",
                        metricID: metric.id,
                        name: "\(metric.name): \(choice)",
                        kind: .yesNo,
                        unit: "",
                        role: metric.role,
                        values: values
                    ))
                }
                continue
            }

            if metric.kind == .medication {
                let relevantEntries = entries.filter { $0.metricID == metric.id && !$0.textValue.isEmpty }
                let days = Dictionary(grouping: relevantEntries) { calendar.startOfDay(for: $0.timestamp) }
                let medicationNames = Set(relevantEntries.map(\.textValue)).sorted()
                for (index, medicationName) in medicationNames.enumerated() {
                    let values = days.mapValues { dayEntries in
                        dayEntries
                            .filter { $0.textValue == medicationName }
                            .compactMap(\.numericValue)
                            .reduce(0, +)
                    }
                    guard !values.isEmpty else { continue }
                    result.append(Series(
                        identity: "\(metric.id.uuidString):medication:\(index)",
                        metricID: metric.id,
                        name: "\(metric.name): \(medicationName)",
                        kind: .number,
                        unit: metric.unit,
                        role: metric.role,
                        values: values
                    ))
                }
                continue
            }

            guard let values = dailyValues[metric.id], !values.isEmpty else { continue }
            if metric.kind == .event, metric.aggregation == .count {
                result.append(Series(
                    identity: metric.id.uuidString,
                    metricID: metric.id,
                    name: metric.name,
                    kind: .yesNo,
                    unit: "",
                    role: metric.role,
                    values: values
                ))
            } else if metric.kind == .choice, !metric.choices.isEmpty {
                for (index, choice) in metric.choices.enumerated() {
                    let selectedValue = Double(index + 1)
                    let binaryValues = values.mapValues { abs($0 - selectedValue) < 0.001 ? 1.0 : 0.0 }
                    result.append(Series(
                        identity: "\(metric.id.uuidString):\(index)",
                        metricID: metric.id,
                        name: "\(metric.name): \(choice)",
                        kind: .yesNo,
                        unit: "",
                        role: metric.role,
                        values: binaryValues
                    ))
                }
            } else {
                result.append(Series(
                    identity: metric.id.uuidString,
                    metricID: metric.id,
                    name: metric.name,
                    kind: metric.kind,
                    unit: metric.unit,
                    role: metric.role,
                    values: values
                ))
            }
        }
        return result
    }

    private static func selectedChoices(in value: String) -> Set<String> {
        Set(value.split(separator: "\u{1F}").map(String.init))
    }

    private static func matchedPairs(
        source: [Date: Double],
        outcome: [Date: Double],
        lag: Int,
        calendar: Calendar
    ) -> [MatchedPair] {
        source.compactMap { day, sourceValue in
            guard let outcomeDay = calendar.date(byAdding: .day, value: lag, to: day),
                  let outcomeValue = outcome[outcomeDay] else { return nil }
            return MatchedPair(
                sourceDate: day,
                outcomeDate: outcomeDay,
                sourceValue: sourceValue,
                outcomeValue: outcomeValue
            )
        }
    }

    private struct MatchedPair {
        let sourceDate: Date
        let outcomeDate: Date
        let sourceValue: Double
        let outcomeValue: Double
    }

    private static func pearson(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        var numerator = 0.0
        var denominatorX = 0.0
        var denominatorY = 0.0
        for index in x.indices {
            let dx = x[index] - meanX
            let dy = y[index] - meanY
            numerator += dx * dy
            denominatorX += dx * dx
            denominatorY += dy * dy
        }
        let denominator = sqrt(denominatorX * denominatorY)
        return denominator > 0 ? numerator / denominator : 0
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        return sqrt(values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1))
    }

    private static func ranks(_ values: [Double]) -> [Double] {
        let sortedIndices = values.indices.sorted { values[$0] < values[$1] }
        var result = Array(repeating: 0.0, count: values.count)
        var position = 0
        while position < sortedIndices.count {
            var end = position
            while end + 1 < sortedIndices.count,
                  abs(values[sortedIndices[end + 1]] - values[sortedIndices[position]]) < 0.000_001 {
                end += 1
            }
            let averageRank = (Double(position + 1) + Double(end + 1)) / 2
            for index in position...end { result[sortedIndices[index]] = averageRank }
            position = end + 1
        }
        return result
    }

    private static func approximatePValue(correlation: Double, sampleCount: Int) -> Double {
        guard sampleCount > 3 else { return 1 }
        let bounded = min(0.999_999, max(-0.999_999, correlation))
        let z = abs(atanh(bounded)) * sqrt(Double(sampleCount - 3))
        return min(1, erfc(z / sqrt(2)))
    }

    private static func applyFalseDiscoveryRate(to candidates: inout [Candidate]) {
        guard !candidates.isEmpty else { return }
        let ordered = candidates.indices.sorted { candidates[$0].pValue < candidates[$1].pValue }
        var nextQ = 1.0
        for reversePosition in stride(from: ordered.count - 1, through: 0, by: -1) {
            let index = ordered[reversePosition]
            let rank = reversePosition + 1
            let q = min(nextQ, candidates[index].pValue * Double(ordered.count) / Double(rank))
            candidates[index].adjustedProbability = min(1, q)
            nextQ = q
        }
    }
}
