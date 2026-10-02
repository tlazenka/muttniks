//
//  QueryParser.swift
//  Puzzola
//
//  Created by Francis Lazenka on 10/1/26.
//

public enum ComparisonOperator: String, Equatable, Sendable {
    case equal = "="
    case notEqual = "!="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="
    case lessThan = "<"
    case lessThanOrEqual = "<="
}

public enum QueryValue: Equatable, Sendable {
    case number(Double)
    case string(String)
    case bool(Bool)
    case null
}

public struct Comparison: Equatable, Sendable {
    public let path: String
    public let operation: ComparisonOperator
    public let value: QueryValue

    public init(path: String, operation: ComparisonOperator, value: QueryValue) {
        self.path = path
        self.operation = operation
        self.value = value
    }
}

public indirect enum Expression: Equatable, Sendable {
    case comparison(Comparison)
    case and(Expression, Expression)
    case or(Expression, Expression)
}

public enum QueryParser {
    static let pathText = Parser<String> { input in
        switch JSONPathParser.path.run(input) {
        case .success((_, let rest)):
            return .success((String(input.source[input.index..<rest.index]), rest))
        case .failure(let error):
            return .failure(error)
        }
    }

    static let operation = oneOf([
        literal(">=").map { _ in ComparisonOperator.greaterThanOrEqual },
        literal("<=").map { _ in ComparisonOperator.lessThanOrEqual },
        literal("!=").map { _ in ComparisonOperator.notEqual },
        literal("=").map { _ in ComparisonOperator.equal },
        literal(">").map { _ in ComparisonOperator.greaterThan },
        literal("<").map { _ in ComparisonOperator.lessThan },
    ])

    static let number = Parser<Double> { input in
        var rest = input
        var text = ""

        if rest.current == "-" {
            text.append("-")
            rest = rest.advance()
        }

        var sawDigit = false
        while let character = rest.current, character.isNumber {
            sawDigit = true
            text.append(character)
            rest = rest.advance()
        }

        if rest.current == "." {
            text.append(".")
            rest = rest.advance()
            while let character = rest.current, character.isNumber {
                sawDigit = true
                text.append(character)
                rest = rest.advance()
            }
        }

        guard sawDigit, let value = Double(text) else {
            return .failure(ParseError(offset: input.offset, expected: "number"))
        }
        return .success((value, rest))
    }

    static let quotedString = Parser<QueryValue> { input in
        guard input.current == "\"" else {
            return .failure(ParseError(offset: input.offset, expected: "value"))
        }
        var rest = input.advance()
        var value = ""
        while let character = rest.current, character != "\"" {
            value.append(character)
            rest = rest.advance()
        }
        guard rest.current == "\"" else {
            return .failure(ParseError(offset: rest.offset, expected: "'\"'"))
        }
        return .success((.string(value), rest.advance()))
    }

    static let value = oneOf([
        quotedString,
        literal("true").map { _ in QueryValue.bool(true) },
        literal("false").map { _ in QueryValue.bool(false) },
        literal("null").map { _ in QueryValue.null },
        number.map(QueryValue.number),
    ])

    public static let comparison =
        token(pathText)
        .flatMap { path in
            token(operation)
                .flatMap { operation in
                    token(value).map { value in
                        Comparison(path: path, operation: operation, value: value)
                    }
                }
        }

    static let conjunction = Parser<Expression> { input in
        switch comparison.run(input) {
        case .failure(let error):
            return .failure(error)
        case .success((let first, var rest)):
            var expression = Expression.comparison(first)

            while true {
                switch token(literal("&&")).run(rest) {
                case .failure:
                    return .success((expression, rest))
                case .success((_, let afterOperator)):
                    switch comparison.run(afterOperator) {
                    case .failure(let error):
                        return .failure(error)
                    case .success((let next, let afterComparison)):
                        expression = .and(expression, .comparison(next))
                        rest = afterComparison
                    }
                }
            }
        }
    }

    public static let expression = Parser<Expression> { input in
        switch conjunction.run(input) {
        case .failure(let error):
            return .failure(error)
        case .success((let first, var rest)):
            var expression = first

            while true {
                switch token(literal("||")).run(rest) {
                case .failure:
                    return .success((expression, rest))
                case .success((_, let afterOperator)):
                    switch conjunction.run(afterOperator) {
                    case .failure(let error):
                        return .failure(error)
                    case .success((let next, let afterConjunction)):
                        expression = .or(expression, next)
                        rest = afterConjunction
                    }
                }
            }
        }
    }

    public static func parse(_ source: String) -> Result<Expression, ParseError> {
        expression.run(ParseInput(source)).flatMap { value, rest in
            guard rest.isAtEnd else {
                return .failure(ParseError(offset: rest.offset, expected: "End of expression"))
            }
            return .success(value)
        }
    }
}

extension QueryParser: ParserProtocol {
}
