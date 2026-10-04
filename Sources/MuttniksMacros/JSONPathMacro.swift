//
//  JSONPathMacro.swift
//  Muttniks
//
//  Created by Francis Lazenka on 10/1/26.
//

import MuttniksParsers
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct JSONPathDiagnostic: DiagnosticMessage {
    let message: String
    var diagnosticID: MessageID { MessageID(domain: "Muttniks", id: "invalid #jsonpath") }
    var severity: DiagnosticSeverity { .error }
}

public struct JSONPathMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard
            let expression = node.arguments.first?.expression,
            let literal = expression.as(StringLiteralExprSyntax.self),
            literal.segments.count == 1,
            case .stringSegment(let segment)? = literal.segments.first
        else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(node),
                    message: JSONPathDiagnostic(message: "#jsonpath only supports a plain string literal")
                )
            )
            return #"JSONPath(validated: "$")"#
        }

        let value = segment.content.text

        switch JSONPathParser.parse(value) {
        case .success:
            return #"JSONPath(validated: \#(literal: value))"#
        case .failure(let error):
            context.diagnose(
                Diagnostic(
                    node: Syntax(expression),
                    message: JSONPathDiagnostic(
                        message: "Invalid JSONPath at offset: \(error.offset) with expected: \(error.expected)"
                    )
                )
            )
            return #"JSONPath(validated: "$")"#
        }
    }
}
