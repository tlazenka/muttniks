import Foundation
import Puzzola

final class QuakesProvider: @unchecked Sendable {
    let database: Database
    let analytics: AnalyticsStore

    init(database: Database) throws {
        self.database = database
        self.analytics = try AnalyticsStore(database: database)
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS earthquake_feed (
                document TEXT NOT NULL CHECK(json_valid(document))
            )
            """
        )
    }

    func refresh() throws {
        guard
            let url = Bundle.main.url(
                forResource: "SampleData",
                withExtension: "json"
            )
        else {
            throw CocoaError(.fileNoSuchFile)
        }

        let document = try String(contentsOf: url, encoding: .utf8)
        try database.execute("DELETE FROM earthquake_feed")
        try database.execute("INSERT INTO earthquake_feed(document) VALUES (\(document))")
    }

}
