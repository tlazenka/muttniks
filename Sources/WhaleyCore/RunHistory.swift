import CSQLite
import Foundation
import QueryBlaster

public enum RunHistoryError: Error {
    case sqlite(String)
    case invalidBinding
}

public struct FlameSuppressionAssessment: Sendable, Equatable, Identifiable {
    public let index: Int
    public let nearbyDeaths: Int
    public let isSuppressed: Bool
    public var id: Int { index }
}

public final class SQLiteRunHistory: @unchecked Sendable {
    let db: OpaquePointer
    let lock = NSLock()
    static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open(path, &handle) == SQLITE_OK, let handle else {
            if let handle { sqlite3_close(handle) }
            throw RunHistoryError.sqlite("Could not open run history")
        }
        db = handle
        do {
            try execute(
                """
                CREATE TABLE IF NOT EXISTS recorded_run (
                  id TEXT PRIMARY KEY,
                  level INTEGER NOT NULL,
                  ended_at REAL NOT NULL,
                  payload BLOB NOT NULL
                );
                CREATE INDEX IF NOT EXISTS recorded_run_level_time ON recorded_run(level, ended_at DESC);
                CREATE TABLE IF NOT EXISTS replay_event (
                  run_id TEXT NOT NULL REFERENCES recorded_run(id) ON DELETE CASCADE,
                  event_time REAL NOT NULL,
                  kind INTEGER NOT NULL CHECK(kind IN (0,1,2)),
                  ordinal INTEGER NOT NULL,
                  document TEXT NOT NULL,
                  PRIMARY KEY (run_id, kind, ordinal)
                ) WITHOUT ROWID;
                CREATE INDEX IF NOT EXISTS replay_event_seek
                  ON replay_event(run_id, event_time, kind, ordinal);
                CREATE TRIGGER IF NOT EXISTS recorded_run_index_events
                AFTER INSERT ON recorded_run
                WHEN json_valid(NEW.payload)
                BEGIN
                  INSERT INTO replay_event(run_id,event_time,kind,ordinal,document)
                  SELECT NEW.id, json_extract(j.value,'$.time'), 0,
                         CAST(j.key AS INTEGER), j.value
                  FROM json_each(NEW.payload, '$.inputs') j
                  WHERE json_type(j.value,'$.time') IN ('integer','real')
                  UNION ALL
                  SELECT NEW.id, json_extract(j.value,'$.time'), 1,
                         CAST(j.key AS INTEGER), j.value
                  FROM json_each(NEW.payload, '$.samples') j
                  WHERE json_type(j.value,'$.time') IN ('integer','real')
                  UNION ALL
                  SELECT NEW.id, json_extract(j.value,'$.time'), 2,
                         CAST(j.key AS INTEGER), j.value
                  FROM json_each(NEW.payload, '$.gameplayEvents') j
                  WHERE json_type(j.value,'$.time') IN ('integer','real');
                END;
                INSERT OR IGNORE INTO replay_event(run_id,event_time,kind,ordinal,document)
                SELECT r.id, json_extract(j.value,'$.time'), 0, CAST(j.key AS INTEGER), j.value
                FROM recorded_run r, json_each(CASE WHEN json_valid(r.payload)
                    THEN r.payload ELSE '{}' END, '$.inputs') j
                WHERE json_type(j.value,'$.time') IN ('integer','real');
                INSERT OR IGNORE INTO replay_event(run_id,event_time,kind,ordinal,document)
                SELECT r.id, json_extract(j.value,'$.time'), 1, CAST(j.key AS INTEGER), j.value
                FROM recorded_run r, json_each(CASE WHEN json_valid(r.payload)
                    THEN r.payload ELSE '{}' END, '$.samples') j
                WHERE json_type(j.value,'$.time') IN ('integer','real');
                INSERT OR IGNORE INTO replay_event(run_id,event_time,kind,ordinal,document)
                SELECT r.id, json_extract(j.value,'$.time'), 2, CAST(j.key AS INTEGER), j.value
                FROM recorded_run r, json_each(CASE WHEN json_valid(r.payload)
                    THEN r.payload ELSE '{}' END, '$.gameplayEvents') j
                WHERE json_type(j.value,'$.time') IN ('integer','real');
                """
            )
        } catch {
            sqlite3_close(handle)
            throw error
        }
    }
    deinit { sqlite3_close(db) }

    public func save(id: UUID, level: Int, endedAt: Date, payload: Data) throws {
        try lock.withLock {
            let statement = try prepare("INSERT OR IGNORE INTO recorded_run(id,level,ended_at,payload) VALUES(?,?,?,?)")
            defer { sqlite3_finalize(statement) }
            try bind(.text(id.uuidString), to: statement, at: 1)
            try bind(.integer(level), to: statement, at: 2)
            sqlite3_bind_double(statement, 3, endedAt.timeIntervalSince1970)
            let result = payload.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, 4, bytes.baseAddress, Int32(bytes.count), Self.transient)
            }
            guard result == SQLITE_OK, sqlite3_step(statement) == SQLITE_DONE else { throw error() }
        }
    }

    public func payloads(level: Int? = nil, limit: Int? = nil) throws -> [Data] {
        try lock.withLock {
            let predicate: QueryPredicate = level.map { .equals(field: "level", value: .integer($0)) } ?? .all([])
            let fragment = try QuerySQLInterpreter.lower(predicate, dialect: .sqlite)
            let statement = try prepare(
                "SELECT payload FROM recorded_run WHERE \(fragment.sql) ORDER BY ended_at DESC, rowid DESC LIMIT ?"
            )
            defer { sqlite3_finalize(statement) }
            for (index, value) in fragment.bindings.enumerated() {
                try bind(value, to: statement, at: Int32(index + 1))
            }
            sqlite3_bind_int64(statement, Int32(fragment.bindings.count + 1), Int64(limit ?? Int.max))
            var results: [Data] = []
            while true {
                let status = sqlite3_step(statement)
                if status == SQLITE_DONE { return results }
                guard status == SQLITE_ROW else { throw error() }
                let length = Int(sqlite3_column_bytes(statement, 0))
                guard let pointer = sqlite3_column_blob(statement, 0) else {
                    if length == 0 {
                        results.append(Data())
                        continue
                    }
                    throw error()
                }
                results.append(Data(bytes: pointer, count: length))
            }
        }
    }

    public func save(_ run: WhaleyRecordedRun) throws {
        try save(
            id: run.id,
            level: run.level,
            endedAt: run.endedAt ?? run.startedAt,
            payload: JSONEncoder().encode(run)
        )
    }

    public func flameSuppressionAssessments(
        level: Int,
        flamePositions: [(x: Double, y: Double)],
        activeRunJSON: Data? = nil,
        limit: Int = 12,
        radius: Double = 60,
        minimumDeaths: Int = 2
    ) throws -> [FlameSuppressionAssessment] {
        guard !flamePositions.isEmpty, limit > 0, radius >= 0, minimumDeaths > 0 else { return [] }
        let positions = flamePositions.enumerated()
            .map { index, point in
                ["index": Double(index), "x": point.x, "y": point.y]
            }
        guard flamePositions.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return [] }
        let flameJSON = try JSONSerialization.data(withJSONObject: positions)
        return try lock.withLock {
            let statement = try prepare(
                """
                WITH candidate AS (
                    SELECT ended_at, rowid AS sequence, CAST(payload AS TEXT) AS document
                    FROM recorded_run WHERE level = ?1
                    UNION ALL
                    SELECT ?2 AS ended_at, 9223372036854775807 AS sequence,
                           CAST(?3 AS TEXT) AS document WHERE ?3 IS NOT NULL
                ), recent AS (
                    SELECT document FROM candidate
                    ORDER BY ended_at DESC, sequence DESC LIMIT ?4
                ), terminal AS (
                    SELECT json_extract(document, '$.samples[#-1].x') AS x,
                           json_extract(document, '$.samples[#-1].y') AS y
                    FROM recent
                    WHERE CASE WHEN json_valid(document)
                        THEN json_extract(document, '$.samples[#-1].dead') = 1
                        ELSE 0 END
                ), flames AS (
                    SELECT CAST(json_extract(value, '$.index') AS INTEGER) AS flame_index,
                           json_extract(value, '$.x') AS x,
                           json_extract(value, '$.y') AS y
                    FROM json_each(?5)
                )
                SELECT f.flame_index, COUNT(t.x) AS nearby_deaths,
                       CASE WHEN COUNT(t.x) >= ?7 THEN 1 ELSE 0 END AS suppressed
                FROM flames f LEFT JOIN terminal t
                  ON (t.x - f.x) * (t.x - f.x) + (t.y - f.y) * (t.y - f.y) <= ?6 * ?6
                GROUP BY f.flame_index
                ORDER BY f.flame_index
                """
            )
            defer { sqlite3_finalize(statement) }
            try bind(.integer(level), to: statement, at: 1)
            sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
            if let activeRunJSON {
                let status = activeRunJSON.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, 3, bytes.baseAddress, Int32(bytes.count), Self.transient)
                }
                guard status == SQLITE_OK else { throw error() }
            } else {
                sqlite3_bind_null(statement, 3)
            }
            try bind(.integer(limit), to: statement, at: 4)
            let status = flameJSON.withUnsafeBytes { bytes in
                sqlite3_bind_text(
                    statement,
                    5,
                    bytes.bindMemory(to: CChar.self).baseAddress,
                    Int32(bytes.count),
                    Self.transient
                )
            }
            guard status == SQLITE_OK else { throw error() }
            sqlite3_bind_double(statement, 6, radius)
            try bind(.integer(minimumDeaths), to: statement, at: 7)
            var assessments: [FlameSuppressionAssessment] = []
            while true {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE { return assessments }
                guard result == SQLITE_ROW else { throw error() }
                assessments.append(
                    FlameSuppressionAssessment(
                        index: Int(sqlite3_column_int(statement, 0)),
                        nearbyDeaths: Int(sqlite3_column_int(statement, 1)),
                        isSuppressed: sqlite3_column_int(statement, 2) != 0
                    )
                )
            }
        }
    }

    func error() -> RunHistoryError { .sqlite(String(cString: sqlite3_errmsg(db))) }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw error() }
    }

    func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw error() }
        return statement
    }

    func bind(_ value: QueryValue, to statement: OpaquePointer, at index: Int32) throws {
        let status: Int32
        switch value {
        case .text(let string):
            status = string.withCString { sqlite3_bind_text(statement, index, $0, -1, Self.transient) }
        case .integer(let number): status = sqlite3_bind_int64(statement, index, Int64(number))
        case .number(let number): status = sqlite3_bind_double(statement, index, number)
        default: throw RunHistoryError.invalidBinding
        }
        guard status == SQLITE_OK else { throw error() }
    }
}
