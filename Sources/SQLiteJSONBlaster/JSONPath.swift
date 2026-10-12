//
//  JSONPath.swift
//  Muttniks
//
//  Created by Francis Lazenka on 10/1/26.
//

public struct JSONPath: Sendable, Hashable {
    public let rawValue: String

    public init(validated rawValue: String) {
        self.rawValue = rawValue
    }
}

@freestanding(expression)
public macro jsonPath(_ value: String) -> JSONPath =
    #externalMacro(module: "MuttniksMacros", type: "JSONPathMacro")
