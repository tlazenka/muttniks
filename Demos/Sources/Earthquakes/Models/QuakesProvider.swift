import Foundation
import SQLiteJSONBlaster

final class QuakesProvider: @unchecked Sendable {
    let database: Database
    let analytics: AnalyticsStore

    init(database: Database) {
        self.database = database
        self.analytics = AnalyticsStore(database: database)
    }

    func prepare() async throws {
        try await database.execute(
            """
            CREATE TABLE IF NOT EXISTS earthquake_feed (
                document TEXT NOT NULL CHECK(json_valid(document))
            )
            """
        )
        try await analytics.prepare()
    }

    func refresh() async throws {
        guard
            let url = Bundle.main.url(
                forResource: "SampleData",
                withExtension: "json"
            )
        else {
            throw CocoaError(.fileNoSuchFile)
        }

        let document = try String(contentsOf: url, encoding: .utf8)
        try await database.execute("DELETE FROM earthquake_feed")
        try await database.execute("INSERT INTO earthquake_feed(document) VALUES (\(document))")
    }

}
