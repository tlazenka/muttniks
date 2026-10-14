import Foundation
import Testing

@testable import WhaleyCore

@Test func historyPersistsAndFiltersByLevel() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("whaley-history-\(UUID()).sqlite3").path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let first = UUID()
    let second = UUID()
    do {
        let store = try SQLiteRunHistory(path: path)
        try store.save(id: first, level: 1, endedAt: Date(timeIntervalSince1970: 10), payload: Data("first".utf8))
        try store.save(id: second, level: 2, endedAt: Date(timeIntervalSince1970: 20), payload: Data("second".utf8))
        try store.save(id: first, level: 1, endedAt: Date(timeIntervalSince1970: 10), payload: Data("duplicate".utf8))
    }
    let reopened = try SQLiteRunHistory(path: path)
    #expect(try reopened.payloads(level: 1) == [Data("first".utf8)])
    #expect(try reopened.payloads(level: 2) == [Data("second".utf8)])
    #expect(try reopened.payloads(limit: 1) == [Data("second".utf8)])
}

@Test func sqlAssessmentExplainsEveryFlame() throws {
    let store = try SQLiteRunHistory(path: ":memory:")
    let run = Data(#"{"samples":[{"x":5,"y":0,"dead":true}]}"#.utf8)
    try store.save(id: UUID(), level: 1, endedAt: Date(timeIntervalSince1970: 1), payload: run)
    try store.save(id: UUID(), level: 1, endedAt: Date(timeIntervalSince1970: 2), payload: run)
    let assessments = try store.flameSuppressionAssessments(level: 1, flamePositions: [(0, 0), (500, 0)])
    #expect(
        assessments == [
            FlameSuppressionAssessment(index: 0, nearbyDeaths: 2, isSuppressed: true),
            FlameSuppressionAssessment(index: 1, nearbyDeaths: 0, isSuppressed: false),
        ]
    )
}

@Test func insightRankingMatchesGameplaySuppression() async throws {
    let history = try SQLiteRunHistory(path: ":memory:")
    for i in 0..<2 {
        try history.save(
            id: UUID(),
            level: 1,
            endedAt: Date(timeIntervalSince1970: Double(i)),
            payload: Data(#"{"samples":[{"x":5,"y":0,"dead":true}]}"#.utf8)
        )
    }
    let assessments = try history.flameSuppressionAssessments(level: 1, flamePositions: [(0, 0), (500, 0)])
    let interpreter = WhaleySQLiteInsightsInterpreter(history: history, level: 1, flames: [(0, 0), (500, 0)])
    let summaries = try await interpreter.execute(.flameRanking)
    #expect(assessments[0].isSuppressed)
    #expect(summaries[0].count == assessments[0].nearbyDeaths)
    #expect(summaries[0].detail.contains("Suppressed"))
}
