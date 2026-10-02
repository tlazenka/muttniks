//
//  Database.swift
//  Puzzola
//
//  Created by Francis Lazenka on 10/1/26.
//

import CSQLite
import Foundation

public enum DatabaseError: Error, CustomStringConvertible {
    case sqlite(String)

    public var description: String {
        switch self {
        case .sqlite(let message): message
        }
    }
}

public struct SQLiteRow {
    let statement: OpaquePointer

    public func string(at index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
            let value = sqlite3_column_text(statement, index)
        else {
            return nil
        }
        return String(cString: value)
    }
}

public final class Database {
    let handle: OpaquePointer

    public init(path: String) throws {
        var database: OpaquePointer?
        guard sqlite3_open(path, &database) == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Could not open SQLite database"
            if let database { sqlite3_close(database) }
            throw DatabaseError.sqlite(message)
        }
        handle = database
    }

    deinit {
        sqlite3_close(handle)
    }

    public func execute(_ sql: SQL) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw error()
        }
    }

    public func query<Result>(
        _ sql: SQL,
        transform: (SQLiteRow) throws -> Result
    ) throws -> [Result] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var results: [Result] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                results.append(try transform(SQLiteRow(statement: statement)))
            case SQLITE_DONE:
                return results
            default:
                throw error()
            }
        }
    }

    func prepare(_ sql: SQL) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql.text, -1, &statement, nil) == SQLITE_OK,
            let statement
        else {
            throw error()
        }

        do {
            for (offset, value) in sql.bindings.enumerated() {
                try bind(value, to: statement, at: Int32(offset + 1))
            }
            return statement
        } catch {
            sqlite3_finalize(statement)
            throw error
        }
    }

    func bind(_ value: SQLiteValue, to statement: OpaquePointer, at index: Int32) throws {
        let result: Int32
        switch value {
        case .integer(let value):
            result = sqlite3_bind_int64(statement, index, value)
        case .real(let value):
            result = sqlite3_bind_double(statement, index, value)
        case .text(let value):
            result = sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        case .blob(let data):
            result = data.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), SQLITE_TRANSIENT)
            }
        case .null:
            result = sqlite3_bind_null(statement, index)
        }

        guard result == SQLITE_OK else { throw error() }
    }

    func error() -> DatabaseError {
        DatabaseError.sqlite(String(cString: sqlite3_errmsg(handle)))
    }
}

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
