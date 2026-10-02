//
//  Parser.swift
//  Puzzola
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

public struct ParseInput: Sendable {
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

    public func advance() -> ParseInput {
        guard !isAtEnd else { return self }
        return ParseInput(
            source: source,
            index: source.index(after: index),
            offset: offset + 1
        )
    }
}

public struct Parser<Output>: Sendable {
    public let run: @Sendable (ParseInput) -> Result<(Output, ParseInput), ParseError>

    public init(
        _ run: @escaping @Sendable (ParseInput) -> Result<(Output, ParseInput), ParseError>
    ) {
        self.run = run
    }

    public func map<T: Sendable>(
        _ transform: @escaping @Sendable (Output) -> T
    ) -> Parser<T> {
        Parser<T> { input in
            self.run(input).map { output, rest in
                (transform(output), rest)
            }
        }
    }

    public func flatMap<T: Sendable>(
        _ transform: @escaping @Sendable (Output) -> Parser<T>
    ) -> Parser<T> {
        Parser<T> { input in
            self.run(input).flatMap { output, rest in
                transform(output).run(rest)
            }
        }
    }
}

public func literal(_ expected: Character) -> Parser<Character> {
    Parser { input in
        guard input.current == expected else {
            return .failure(ParseError(offset: input.offset, expected: "'\(expected)'"))
        }
        return .success((expected, input.advance()))
    }
}

public func prefix(
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
            switch parser.run(input) {
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
            switch parser.run(rest) {
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

public func literal(_ expected: String) -> Parser<String> {
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

protocol ParserProtocol {
    associatedtype Output

    static func parse(_ source: String) -> Result<Output, ParseError>
}
