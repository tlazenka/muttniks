//
//  QueryParser.swift
//  Muttniks
//
//  Created by Francis Lazenka on 10/1/26.
//
import Do

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
        switch JSONPathParser.path.parse(input) {
        case .success((_, let rest)):
            return .success((String(input.source[input.index..<rest.index]), rest))
        case .failure(let error):
            return .failure(error)
        }
    }

    static let operation = oneOf([
        const(">=").map { _ in ComparisonOperator.greaterThanOrEqual },
        const("<=").map { _ in ComparisonOperator.lessThanOrEqual },
        const("!=").map { _ in ComparisonOperator.notEqual },
        const("=").map { _ in ComparisonOperator.equal },
        const(">").map { _ in ComparisonOperator.greaterThan },
        const("<").map { _ in ComparisonOperator.lessThan },
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
        const("true").map { _ in QueryValue.bool(true) },
        const("false").map { _ in QueryValue.bool(false) },
        const("null").map { _ in QueryValue.null },
        number.map(QueryValue.number),
    ])

    @Do
    static func parseComparison(
        _ input: CharStream
    ) -> Result<(Comparison, CharStream), ParseError> {
        let (path, afterPath) = #bind(token(pathText).parse(input))
        let (operation, afterOperation) = #bind(token(operation).parse(afterPath))
        let (value, rest) = #bind(token(value).parse(afterOperation))
        (Comparison(path: path, operation: operation, value: value), rest)
    }

    public static let comparison = Parser<Comparison> { input in
        parseComparison(input)
    }

    static let conjunction = Parser<Expression> { input in
        switch comparison.parse(input) {
        case .failure(let error):
            return .failure(error)
        case .success((let first, var rest)):
            var expression = Expression.comparison(first)

            while true {
                switch token(const("&&")).parse(rest) {
                case .failure:
                    return .success((expression, rest))
                case .success((_, let afterOperator)):
                    switch comparison.parse(afterOperator) {
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
        switch conjunction.parse(input) {
        case .failure(let error):
            return .failure(error)
        case .success((let first, var rest)):
            var expression = first

            while true {
                switch token(const("||")).parse(rest) {
                case .failure:
                    return .success((expression, rest))
                case .success((_, let afterOperator)):
                    switch conjunction.parse(afterOperator) {
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
        expression.parse(CharStream(source)).flatMap { value, rest in
            guard rest.isAtEnd else {
                return .failure(ParseError(offset: rest.offset, expected: "End of expression"))
            }
            return .success(value)
        }
    }
}

extension QueryParser: ParserProtocol {
}
