//
//  SQL.swift
//  Muttniks
//
//  Created by Francis Lazenka on 10/1/26.
//

import Foundation
import MuttniksParsers

public enum SQLiteValue: Sendable, Equatable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null
}

public protocol SQLiteBindable {
    var sqliteValue: SQLiteValue { get }
}

extension Int: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .integer(Int64(self)) }
}

extension Int64: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .integer(self) }
}

extension Double: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .real(self) }
}

extension String: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .text(self) }
}

extension Data: SQLiteBindable {
    public var sqliteValue: SQLiteValue { .blob(self) }
}

public struct SQL: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, Sendable {
    public let text: String
    public let bindings: [SQLiteValue]

    public init(stringLiteral value: String) {
        text = value
        bindings = []
    }

    public init(stringInterpolation: StringInterpolation) {
        text = stringInterpolation.text
        bindings = stringInterpolation.bindings
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        var text = ""
        var bindings: [SQLiteValue] = []

        public init(literalCapacity: Int, interpolationCount: Int) {
            text.reserveCapacity(literalCapacity)
            bindings.reserveCapacity(interpolationCount)
        }

        public mutating func appendLiteral(_ literal: String) {
            text += literal
        }

        public mutating func appendInterpolation<T: SQLiteBindable>(_ value: T) {
            text += "?"
            bindings.append(value.sqliteValue)
        }

        public mutating func appendInterpolation(jsonPath path: JSONPath) {
            text += "?"
            bindings.append(.text(path.rawValue))
        }
    }
}

public extension SQL {
    static func earthquakeIDs(matching expression: MuttniksParsers.Expression) -> SQL {
        var interpolation = SQL.StringInterpolation(
            literalCapacity: 320,
            interpolationCount: 4
        )
        interpolation.appendLiteral(
            """
            SELECT json_extract(feature.value, '$.id')
            FROM earthquake_feed,
                 json_each(document, '$.features') AS feature
            WHERE 
            """
        )
        append(expression, to: &interpolation)
        return SQL(stringInterpolation: interpolation)
    }

    static func append(
        _ expression: MuttniksParsers.Expression,
        to interpolation: inout SQL.StringInterpolation
    ) {
        switch expression {
        case .comparison(let comparison):
            interpolation.appendLiteral("(json_extract(feature.value, ")
            interpolation.appendInterpolation(
                jsonPath: JSONPath(validated: comparison.path)
            )
            if case .null = comparison.value {
                let nullOperator = comparison.operation == .notEqual ? "IS NOT" : "IS"
                interpolation.appendLiteral(") \(nullOperator) NULL)")
            } else {
                interpolation.appendLiteral(") \(comparison.operation.rawValue) ")
                switch comparison.value {
                case .number(let value):
                    interpolation.appendInterpolation(value)
                case .string(let value):
                    interpolation.appendInterpolation(value)
                case .bool(let value):
                    interpolation.appendInterpolation(value ? 1 : 0)
                case .null:
                    break
                }
                interpolation.appendLiteral(")")
            }

        case .and(let lhs, let rhs):
            interpolation.appendLiteral("(")
            append(lhs, to: &interpolation)
            interpolation.appendLiteral(" AND ")
            append(rhs, to: &interpolation)
            interpolation.appendLiteral(")")

        case .or(let lhs, let rhs):
            interpolation.appendLiteral("(")
            append(lhs, to: &interpolation)
            interpolation.appendLiteral(" OR ")
            append(rhs, to: &interpolation)
            interpolation.appendLiteral(")")
        }
    }
}
