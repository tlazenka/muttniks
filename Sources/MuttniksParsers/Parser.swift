//
//  Parser.swift
//  Muttniks
//
//  Created by Francis Lazenka on 10/1/26.
//

public struct ParseError: Error, Equatable, Sendable {
    public let offset: Int
    public let expected: String

    public init(offset: Int, expected: String) {
        self.offset = offset
        self.expected = expected
    }
}

public struct CharStream: Sendable {
    public let source: String
    public let index: String.Index
    public let offset: Int

    public init(_ source: String) {
        self.source = source
        self.index = source.startIndex
        self.offset = 0
    }

    init(source: String, index: String.Index, offset: Int) {
        self.source = source
        self.index = index
        self.offset = offset
    }

    public var isAtEnd: Bool { index == source.endIndex }
    public var current: Character? { isAtEnd ? nil : source[index] }

    public func advance() -> CharStream {
        guard !isAtEnd else { return self }
        return CharStream(
            source: source,
            index: source.index(after: index),
            offset: offset + 1
        )
    }
}

public struct Parser<Output>: Sendable {
    public let parse: @Sendable (CharStream) -> Result<(Output, CharStream), ParseError>

    public init(
        _ parse: @escaping @Sendable (CharStream) -> Result<(Output, CharStream), ParseError>
    ) {
        self.parse = parse
    }

    public func map<T: Sendable>(
        _ transform: @escaping @Sendable (Output) -> T
    ) -> Parser<T> {
        Parser<T> { input in
            self.parse(input).map { output, rest in
                (transform(output), rest)
            }
        }
    }

    public func flatMap<T: Sendable>(
        _ transform: @escaping @Sendable (Output) -> Parser<T>
    ) -> Parser<T> {
        Parser<T> { input in
            self.parse(input).flatMap { output, rest in
                transform(output).parse(rest)
            }
        }
    }
}

public func const(_ expected: Character) -> Parser<Character> {
    Parser { input in
        guard input.current == expected else {
            return .failure(ParseError(offset: input.offset, expected: "'\(expected)'"))
        }
        return .success((expected, input.advance()))
    }
}

public func regex(
    while predicate: @escaping @Sendable (Character) -> Bool,
    expected: String
) -> Parser<String> {
    Parser { input in
        var rest = input
        var value = ""

        while let character = rest.current, predicate(character) {
            value.append(character)
            rest = rest.advance()
        }

        guard !value.isEmpty else {
            return .failure(ParseError(offset: input.offset, expected: expected))
        }

        return .success((value, rest))
    }
}

public func oneOf<T: Sendable>(_ parsers: [Parser<T>]) -> Parser<T> {
    Parser { input in
        var best = ParseError(offset: input.offset, expected: "alternative")
        for parser in parsers {
            switch parser.parse(input) {
            case .success(let result):
                return .success(result)
            case .failure(let error) where error.offset >= best.offset:
                best = error
            case .failure:
                break
            }
        }
        return .failure(best)
    }
}

public func many<T: Sendable>(_ parser: Parser<T>) -> Parser<[T]> {
    Parser { input in
        var rest = input
        var values: [T] = []

        while true {
            switch parser.parse(rest) {
            case .success(let (value, next)):
                guard next.offset > rest.offset else { return .success((values, rest)) }
                values.append(value)
                rest = next
            case .failure:
                return .success((values, rest))
            }
        }
    }
}

public func const(_ expected: String) -> Parser<String> {
    Parser { input in
        var rest = input
        for character in expected {
            guard rest.current == character else {
                return .failure(
                    ParseError(offset: rest.offset, expected: "'\(expected)'")
                )
            }
            rest = rest.advance()
        }
        return .success((expected, rest))
    }
}

public let whitespace = Parser<Void> { input in
    var rest = input
    while let character = rest.current, character.isWhitespace {
        rest = rest.advance()
    }
    return .success(((), rest))
}

public func token<T: Sendable>(_ parser: Parser<T>) -> Parser<T> {
    whitespace.flatMap { _ in
        parser.flatMap { value in
            whitespace.map { _ in value }
        }
    }
}

public func satisfy(
    _ predicate: @escaping @Sendable (Character) -> Bool,
    expected: String
) -> Parser<Character> {
    Parser { input in
        guard let current = input.current, predicate(current) else {
            return .failure(ParseError(offset: input.offset, expected: expected))
        }
        return .success((current, input.advance()))
    }
}

public func token<A: Sendable, B: Sendable>(
    _ parser: Parser<A>,
    value: B
) -> Parser<B> {
    parser.map { _ in value }
}

public func many1<T: Sendable>(_ parser: Parser<T>) -> Parser<[T]> {
    parser.flatMap { first in many(parser).map { [first] + $0 } }
}

public func sepby<T: Sendable, S: Sendable>(
    _ parser: Parser<T>,
    separator: Parser<S>
) -> Parser<[T]> {
    oneOf([
        parser.flatMap { first in
            many(separator.flatMap { _ in parser }).map { [first] + $0 }
        },
        Parser { input in .success(([], input)) },
    ])
}

infix operator |> : AdditionPrecedence
public func |> <A: Sendable, B: Sendable>(
    parser: Parser<A>,
    transform: @escaping @Sendable (A) -> B
) -> Parser<B> { parser.map(transform) }

infix operator | : AdditionPrecedence
public func | <T: Sendable>(lhs: Parser<T>, rhs: Parser<T>) -> Parser<T> {
    oneOf([lhs, rhs])
}

infix operator ~> : MultiplicationPrecedence
public func ~> <A: Sendable, B: Sendable>(lhs: Parser<A>, rhs: Parser<B>) -> Parser<A> {
    lhs.flatMap { value in rhs.map { _ in value } }
}

infix operator >~ : MultiplicationPrecedence
public func >~ <A: Sendable, B: Sendable>(lhs: Parser<A>, rhs: Parser<B>) -> Parser<B> {
    lhs.flatMap { _ in rhs }
}

infix operator ~>~ : MultiplicationPrecedence
public func ~>~ <A: Sendable, B: Sendable>(lhs: Parser<A>, rhs: Parser<B>) -> Parser<(A, B)> {
    lhs.flatMap { a in rhs.map { b in (a, b) } }
}

protocol ParserProtocol {
    associatedtype Output

    static func parse(_ source: String) -> Result<Output, ParseError>
}

// Not going to update use sites just yet
public typealias ParseInput = CharStream

public extension Parser {
    @available(*, deprecated, renamed: "parse")
    var run: @Sendable (CharStream) -> Result<(Output, CharStream), ParseError> { parse }
}

@available(*, deprecated, renamed: "const")
public func literal(_ expected: Character) -> Parser<Character> { const(expected) }
@available(*, deprecated, renamed: "const")
public func literal(_ expected: String) -> Parser<String> { const(expected) }
@available(*, deprecated, renamed: "regex")
public func prefix(
    while predicate: @escaping @Sendable (Character) -> Bool,
    expected: String
) -> Parser<String> { regex(while: predicate, expected: expected) }
