import Foundation

public enum WhaleyInsightQuery: Sendable, Equatable {
    case flameRanking
}

public struct WhaleyInsightSummary: Sendable, Equatable {
    public let title: String
    public let detail: String
    public let count: Int
    public init(title: String, detail: String, count: Int) {
        self.title = title
        self.detail = detail
        self.count = count
    }
}

public struct WhaleySQLiteInsightsInterpreter: @unchecked Sendable {
    public typealias Query = WhaleyInsightQuery
    public typealias Output = [WhaleyInsightSummary]
    let history: SQLiteRunHistory
    let level: Int
    let flames: [(x: Double, y: Double)]
    let activeRunJSON: Data?

    public init(history: SQLiteRunHistory, level: Int, flames: [(x: Double, y: Double)], activeRunJSON: Data? = nil) {
        self.history = history
        self.level = level
        self.flames = flames
        self.activeRunJSON = activeRunJSON
    }

    public func execute(_ query: WhaleyInsightQuery) async throws -> [WhaleyInsightSummary] {
        switch query {
        case .flameRanking:
            return
                try history.flameSuppressionAssessments(
                    level: level,
                    flamePositions: flames,
                    activeRunJSON: activeRunJSON
                )
                .sorted { $0.nearbyDeaths == $1.nearbyDeaths ? $0.index < $1.index : $0.nearbyDeaths > $1.nearbyDeaths }
                .map {
                    WhaleyInsightSummary(
                        title: "Flame \($0.index + 1)",
                        detail: "\($0.nearbyDeaths) nearby deaths (\($0.isSuppressed ? "Suppressed" : "Active"))",
                        count: $0.nearbyDeaths
                    )
                }
        }
    }
}
