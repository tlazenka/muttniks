//
//  QueryExpression.swift
//  Puzzola
//
//  Created by Francis Lazenka on 10/1/26.
//

import PuzzolaParsers

public enum QueryExpressionError: Error, CustomStringConvertible {
    case invalid(offset: Int, expected: String)

    public var description: String {
        switch self {
        case .invalid(let offset, let expected):
            "Invalid expression at offset: \(offset) with expected: \(expected)"
        }
    }
}

public func parseQueryExpression(_ source: String) throws -> Expression {
    switch QueryParser.parse(source) {
    case .success(let comparison):
        return comparison
    case .failure(let error):
        throw QueryExpressionError.invalid(
            offset: error.offset,
            expected: error.expected
        )
    }
}
