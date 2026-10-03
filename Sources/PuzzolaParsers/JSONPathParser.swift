//
//  JSONPathParser.swift
//  Puzzola
//
//  Created by Francis Lazenka on 10/1/26.
//

public enum JSONPathComponent: Equatable, Sendable {
    case member(String)
    case index(Int)
    case fromEnd(Int)
    case append
}

public struct ParsedJSONPath: Equatable, Sendable {
    public let components: [JSONPathComponent]

    public init(components: [JSONPathComponent]) {
        self.components = components
    }
}

public enum JSONPathParser {
    static let identifier = prefix(
        while: { $0.isLetter || $0.isNumber || $0 == "_" },
        expected: "name"
    )

    static let digits = prefix(
        while: { $0.isNumber },
        expected: "integer"
    )

    static let member =
        literal(".")
        .flatMap { _ in identifier }
        .map(JSONPathComponent.member)

    static let index =
        literal("[")
        .flatMap { _ in digits }
        .flatMap { digits in
            literal("]").map { _ in
                JSONPathComponent.index(Int(digits)!)
            }
        }

    static let fromEnd =
        literal("[")
        .flatMap { _ in literal("#") }
        .flatMap { _ in literal("-") }
        .flatMap { _ in digits }
        .flatMap { digits in
            literal("]").map { _ in
                JSONPathComponent.fromEnd(Int(digits)!)
            }
        }

    static let append =
        literal("[")
        .flatMap { _ in literal("#") }
        .flatMap { _ in literal("]") }
        .map { _ in JSONPathComponent.append }

    static let component = oneOf([
        member,
        fromEnd,
        append,
        index,
    ])

    public static let path =
        literal("$")
        .flatMap { _ in many(component) }
        .map(ParsedJSONPath.init)

    public static func parse(_ source: String) -> Result<ParsedJSONPath, ParseError> {
        path.run(ParseInput(source)).flatMap { value, rest in
            guard rest.isAtEnd else {
                return .failure(
                    ParseError(offset: rest.offset, expected: "JSONPath component")
                )
            }
            return .success(value)
        }
    }
}

extension JSONPathParser: ParserProtocol {
}
