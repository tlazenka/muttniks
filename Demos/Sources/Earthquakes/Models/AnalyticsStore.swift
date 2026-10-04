import Foundation
import Muttniks

struct FieldMarker: Equatable {
    let label: String
}

struct WrappedInsight: Identifiable {
    let id: String
    let eyebrow: String
    let value: String
    let detail: String
}

final class AnalyticsStore: @unchecked Sendable {
    let database: Database

    init(database: Database) throws {
        self.database = database
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS analytics (
                id INTEGER PRIMARY KEY,
                occurred_at REAL NOT NULL,
                event TEXT NOT NULL,
                properties TEXT NOT NULL CHECK(json_valid(properties))
            )
            """
        )
    }

    func record(_ event: String, properties: [String: Any] = [:]) {
        guard JSONSerialization.isValidJSONObject(properties),
            let data = try? JSONSerialization.data(withJSONObject: properties),
            let json = String(data: data, encoding: .utf8)
        else { return }

        try? database.execute(
            """
            INSERT INTO analytics(occurred_at, event, properties)
            VALUES (\(Date().timeIntervalSince1970), \(event), \(json))
            """
        )
    }

    func fieldMarkers() throws -> [String: FieldMarker] {
        let rows = try database.query(
            """
            WITH completed AS (
              SELECT id, occurred_at,
                     json_extract(properties, '$.path') AS path
              FROM analytics
              WHERE event = 'filter_finished'
                AND json_extract(properties, '$.path') IS NOT NULL
            ),
            bounds AS (
              SELECT MIN(occurred_at) AS first_at,
                     MAX(occurred_at) AS last_at
              FROM completed
            ),
            stats AS (
              SELECT path,
                     COUNT(*) AS uses,
                     MIN(occurred_at) AS first_use,
                     SUM(CASE
                           WHEN occurred_at >=
                             (SELECT first_at + (last_at - first_at) / 2.0 FROM bounds)
                           THEN 1 ELSE 0
                         END) AS recent_uses,
                     SUM(CASE
                           WHEN occurred_at <
                             (SELECT first_at + (last_at - first_at) / 2.0 FROM bounds)
                           THEN 1 ELSE 0
                         END) AS older_uses
              FROM completed
              GROUP BY path
            ),
            ranked AS (
              SELECT *,
                     DENSE_RANK() OVER (ORDER BY uses DESC) AS popularity_rank
              FROM stats
            )
            SELECT path,
                   CASE
                     WHEN popularity_rank <= 3 THEN 'POPULAR'
                     WHEN recent_uses >= 2 AND recent_uses >= MAX(1, older_uses * 2)
                       THEN 'TRENDING'
                     WHEN uses >= 3 THEN 'FREQUENT'
                     WHEN first_use >=
                       (SELECT first_at + (last_at - first_at) / 2.0 FROM bounds)
                       THEN 'NEW'
                     ELSE NULL
                   END AS marker
            FROM ranked
            WHERE marker IS NOT NULL
            """
        ) { row in
            (row.string(at: 0) ?? "", row.string(at: 1) ?? "")
        }

        var result: [String: FieldMarker] = [:]
        for (path, label) in rows where !path.isEmpty && !label.isEmpty {
            result[path] = FieldMarker(label: label)
        }
        return result
    }

    func suggestionScores() throws -> [String: Int] {
        let rows = try database.query(
            """
            WITH completed AS (
              SELECT id, occurred_at,
                     json_extract(properties, '$.path') AS path
              FROM analytics
              WHERE event = 'filter_finished'
                AND json_extract(properties, '$.path') IS NOT NULL
            ),
            ranked AS (
              SELECT path,
                     COUNT(*) AS uses,
                     MAX(occurred_at) AS last_used,
                     DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS frequency_rank,
                     DENSE_RANK() OVER (ORDER BY MAX(occurred_at) DESC) AS recency_rank
              FROM completed
              GROUP BY path
            )
            SELECT path,
                   (1000 - frequency_rank * 50) +
                   (500 - recency_rank * 20) +
                   MIN(uses, 20) * 10 AS score
            FROM ranked
            """
        ) { row in
            (row.string(at: 0) ?? "", row.int(at: 1))
        }
        return Dictionary(uniqueKeysWithValues: rows.filter { !$0.0.isEmpty })
    }

    func nextFieldScores(after path: String) throws -> [String: Int] {
        let rows = try database.query(
            """
            WITH committed AS (
              SELECT id, occurred_at,
                     json_extract(properties, '$.path') AS path
              FROM analytics
              WHERE event IN ('filter_finished', 'filter_suggestion_selected')
                AND json_extract(properties, '$.path') IS NOT NULL
            ),
            sequenced AS (
              SELECT path,
                     LEAD(path) OVER (ORDER BY occurred_at, id) AS next_path
              FROM committed
            ),
            transitions AS (
              SELECT next_path, COUNT(*) AS uses
              FROM sequenced
              WHERE path = \(path)
                AND next_path IS NOT NULL
                AND next_path <> path
              GROUP BY next_path
            ),
            ranked AS (
              SELECT next_path, uses,
                     DENSE_RANK() OVER (ORDER BY uses DESC) AS transition_rank
              FROM transitions
            )
            SELECT next_path,
                   (1000 - transition_rank * 50) + MIN(uses, 20) * 20 AS score
            FROM ranked
            ORDER BY score DESC, next_path
            """
        ) { row in
            (row.string(at: 0) ?? "", row.int(at: 1))
        }
        return Dictionary(uniqueKeysWithValues: rows.filter { !$0.0.isEmpty })
    }

    func wrapped() throws -> [WrappedInsight] {
        var result: [WrappedInsight] = []

        let totalScrubs =
            try database.query(
                """
                SELECT COUNT(*)
                FROM analytics
                WHERE event = 'filter_finished'
                """
            ) { row in row.int(at: 0) }.first ?? 0
        result.append(
            .init(
                id: "totalScrubs",
                eyebrow: "Not no scrubs",
                value: "\(totalScrubs) scrubs",
                detail: "done on this app install"
            )

        )

        let favoriteFilterField = try database.query(
            """
            WITH counts AS (
              SELECT json_extract(properties, '$.path') AS path, COUNT(*) AS uses
              FROM analytics
              WHERE event = 'filter_finished'
              GROUP BY path
            ),
            ranked AS (
              SELECT path, uses,
                     RANK() OVER (ORDER BY uses DESC) AS popularity_rank
              FROM counts
            )
            SELECT path, uses FROM ranked
            WHERE popularity_rank = 1
            ORDER BY path
            LIMIT 1
            """
        ) { row in
            (row.string(at: 0) ?? "—", row.int(at: 1))
        }.first
        if let favoriteFilterField {
            result.append(
                .init(
                    id: "favoriteFilterField",
                    eyebrow: "The apple of your eye",
                    value: favoriteFilterField.0,
                    detail: "refined your result set \(favoriteFilterField.1) times"
                )
            )
        }

        let medianResultCount = try database.query(
            """
            WITH ordered AS (
              SELECT CAST(json_extract(properties, '$.resultsAfter') AS INTEGER) AS result_count,
                     ROW_NUMBER() OVER (
                       ORDER BY CAST(json_extract(properties, '$.resultsAfter') AS INTEGER)
                     ) AS row_number,
                     COUNT(*) OVER () AS total
              FROM analytics
              WHERE event = 'filter_finished'
            )
            SELECT AVG(result_count)
            FROM ordered
            WHERE row_number IN ((total + 1) / 2, (total + 2) / 2)
            """
        ) { row in row.double(at: 0) }.first
        if let medianResultCount {
            result.append(
                .init(
                    id: "medianResultCount",
                    eyebrow: "How things shake out",
                    value: "\(Int(medianResultCount.rounded())) median earthquakes",
                    detail: "remain after you filter"
                )
            )
        }

        let effectiveFilter = try database.query(
            """
            WITH ranked AS (
              SELECT json_extract(properties, '$.description') AS description,
                     CAST(json_extract(properties, '$.resultsAfter') AS INTEGER) AS result_count,
                     ROW_NUMBER() OVER (
                       ORDER BY CAST(json_extract(properties, '$.resultsAfter') AS INTEGER), id
                     ) AS selectivity_rank
              FROM analytics
              WHERE event = 'filter_finished'
            )
            SELECT description, result_count
            FROM ranked
            WHERE selectivity_rank = 1
            """
        ) { row in
            (row.string(at: 0) ?? "—", row.int(at: 1))
        }.first
        if let effectiveFilter {
            result.append(
                .init(
                    id: "effectiveFilter",
                    eyebrow: "Great Filter",
                    value: effectiveFilter.0,
                    detail: "left \(effectiveFilter.1) earthquake(s) remaining"
                )
            )
        }

        let sessionSummary = try database.query(
            """
            WITH ordered AS (
              SELECT id, occurred_at,
                     LAG(occurred_at) OVER (ORDER BY occurred_at, id) AS previous_at
              FROM analytics
            ),
            boundaries AS (
              SELECT id, occurred_at,
                     CASE
                       WHEN previous_at IS NULL OR occurred_at - previous_at > 1800
                       THEN 1 ELSE 0
                     END AS starts_session
              FROM ordered
            ),
            sessionized AS (
              SELECT id, occurred_at,
                     SUM(starts_session) OVER (
                       ORDER BY occurred_at, id
                       ROWS UNBOUNDED PRECEDING
                     ) AS session_id
              FROM boundaries
            ),
            sessions AS (
              SELECT session_id,
                     MIN(occurred_at) AS started_at,
                     MAX(occurred_at) AS ended_at,
                     COUNT(*) AS events
              FROM sessionized
              GROUP BY session_id
            )
            SELECT COUNT(*),
                   COALESCE(MAX(events), 0),
                   COALESCE(MAX(ended_at - started_at), 0)
            FROM sessions
            """
        ) { row in
            (row.int(at: 0), row.int(at: 1), row.double(at: 2))
        }.first

        if let sessionSummary, sessionSummary.0 > 0 {
            result.append(
                .init(
                    id: "sessionSummary",
                    eyebrow: "Sessions",
                    value: "\(sessionSummary.0) interactions",
                    detail: "made up your scrubbiest session \(sessionSummary.1)"
                )
            )
        }

        let upNext = try database.query(
            """
            WITH filters AS (
              SELECT id, occurred_at,
                     json_extract(properties, '$.path') AS path,
                     LEAD(json_extract(properties, '$.path'))
                       OVER (ORDER BY occurred_at, id) AS next_path
              FROM analytics
              WHERE event = 'filter_finished'
            ),
            transitions AS (
              SELECT path, next_path, COUNT(*) AS uses
              FROM filters
              WHERE next_path IS NOT NULL AND path <> next_path
              GROUP BY path, next_path
            ),
            ranked AS (
              SELECT path, next_path, uses,
                     ROW_NUMBER() OVER (ORDER BY uses DESC, path, next_path) AS rank
              FROM transitions
            )
            SELECT path, next_path, uses
            FROM ranked
            WHERE rank = 1
            """
        ) { row in
            (
                row.string(at: 0) ?? "—",
                row.string(at: 1) ?? "—",
                row.int(at: 2)
            )
        }.first

        if let upNext {
            result.append(
                .init(
                    id: "upNext",
                    eyebrow: "Up Next",
                    value: "\(upNext.0) → \(upNext.1)",
                    detail: "followed each other \(upNext.2) time(s)"
                )
            )
        }

        let dockerPasteboardCopies =
            try database.query(
                """
                SELECT COUNT(*)
                FROM analytics
                WHERE event = 'docker_command_copied'
                """
            ) { row in row.int(at: 0) }.first ?? 0
        result.append(
            .init(
                id: "dockerPasteboardCopies",
                eyebrow: "I hope you read the README",
                value: "\(dockerPasteboardCopies) Docker commands",
                detail: "copied to your pasteboard, perhaps unwittingly"
            )
        )

        return result
    }
}
