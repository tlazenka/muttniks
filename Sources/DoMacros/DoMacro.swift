//
//  DoMacro.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import SwiftBasicFormat
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct DoMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let body = declaration.body else {
            return []
        }

        let transformed = CodeBlockSyntax(
            leftBrace: .leftBraceToken(),
            statements: transform(body.statements, liftFinalExpression: true),
            rightBrace: .rightBraceToken()
        )
        let formatted = transformed.formatted().as(CodeBlockSyntax.self) ?? transformed
        return Array(formatted.statements)
    }

    static func transform(
        _ statements: CodeBlockItemListSyntax,
        liftFinalExpression: Bool = false
    ) -> CodeBlockItemListSyntax {
        transform(Array(statements)[...], liftFinalExpression: liftFinalExpression)
    }

    private static func transform(
        _ statements: ArraySlice<CodeBlockItemSyntax>,
        liftFinalExpression: Bool
    ) -> CodeBlockItemListSyntax {
        guard let first = statements.first else {
            return CodeBlockItemListSyntax([])
        }

        let rest = statements.dropFirst()

        if let bind = Bind(first) {
            if rest.isEmpty, liftFinalExpression, case .discard = bind.kind {
                let tail: StmtSyntax = "return \(bind.expression.trimmed)"
                return CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .stmt(tail))
                ])
            }

            let continuation = transform(rest, liftFinalExpression: liftFinalExpression)
            return CodeBlockItemListSyntax([
                makeBindSwitch(bind, continuation: continuation)
            ])
        }

        if rest.isEmpty, liftFinalExpression,
            let expression = first.item.as(ExprSyntax.self)
        {
            return CodeBlockItemListSyntax([
                liftFinalExpressionItem(expression)
            ])
        }

        let transformedFirst = transformNonBind(first)
        let transformedRest = transform(rest, liftFinalExpression: liftFinalExpression)
        return CodeBlockItemListSyntax([transformedFirst] + Array(transformedRest))
    }

    private static func liftFinalExpressionItem(
        _ expression: ExprSyntax
    ) -> CodeBlockItemSyntax {
        if isExplicitResult(expression) {
            let statement: StmtSyntax = "return \(expression.trimmed)"
            return CodeBlockItemSyntax(item: .stmt(statement))
        }

        let statement: StmtSyntax = "return .success(\(expression.trimmed))"
        return CodeBlockItemSyntax(item: .stmt(statement))
    }

    private static func transformNonBind(
        _ item: CodeBlockItemSyntax
    ) -> CodeBlockItemSyntax {
        if let returnStatement = item.item.as(ReturnStmtSyntax.self),
            let expression = returnStatement.expression
        {
            if let bound = bindExpression(expression) {
                let tail: StmtSyntax = "return \(bound.trimmed)"
                return CodeBlockItemSyntax(item: .stmt(tail))
            }

            if isExplicitResult(expression) {
                return item
            }

            let wrapped: StmtSyntax = "return .success(\(expression.trimmed))"
            return CodeBlockItemSyntax(item: .stmt(wrapped))
        }

        let rewritten = NestedBlockRewriter().rewrite(Syntax(item))
        return rewritten.as(CodeBlockItemSyntax.self) ?? item
    }

    private static func isExplicitResult(_ expression: ExprSyntax) -> Bool {
        guard let call = expression.as(FunctionCallExprSyntax.self),
            let member = call.calledExpression.as(MemberAccessExprSyntax.self)
        else {
            return false
        }

        switch member.declName.baseName.text {
        case "success", "failure":
            return true
        default:
            return false
        }
    }

    private struct Bind {
        enum BindingKind {
            case `let`(PatternSyntax)
            case `var`(PatternSyntax)
            case discard
        }

        let kind: BindingKind
        let expression: ExprSyntax

        init?(_ item: CodeBlockItemSyntax) {
            if let variable = item.item.as(VariableDeclSyntax.self),
                variable.bindings.count == 1,
                let binding = variable.bindings.first,
                let initializer = binding.initializer,
                let boundExpression = DoMacro.bindExpression(initializer.value)
            {
                switch variable.bindingSpecifier.tokenKind {
                case .keyword(.let):
                    self.kind = .let(binding.pattern.trimmed)
                case .keyword(.var):
                    self.kind = .var(binding.pattern.trimmed)
                default:
                    return nil
                }

                self.expression = boundExpression.trimmed
                return
            }

            if let expression = item.item.as(ExprSyntax.self),
                let boundExpression = DoMacro.bindExpression(expression)
            {
                self.kind = .discard
                self.expression = boundExpression.trimmed
                return
            }

            return nil
        }
    }

    private static func bindExpression(_ expression: ExprSyntax) -> ExprSyntax? {
        guard let macro = expression.as(MacroExpansionExprSyntax.self),
            macro.macroName.text == "bind",
            macro.arguments.count == 1,
            let argument = macro.arguments.first,
            argument.label == nil,
            macro.trailingClosure == nil,
            macro.additionalTrailingClosures.isEmpty
        else {
            return nil
        }

        return argument.expression.trimmed
    }

    private static func makeBindSwitch(
        _ bind: Bind,
        continuation: CodeBlockItemListSyntax
    ) -> CodeBlockItemSyntax {
        let successPattern: String

        switch bind.kind {
        case .let(let pattern):
            successPattern = "let \(pattern.trimmedDescription)"
        case .var(let pattern):
            successPattern = "var \(pattern.trimmedDescription)"
        case .discard:
            successPattern = "_"
        }

        let continuationSource =
            continuation
            .map { $0.trimmedDescription }
            .joined(separator: "\n")

        let successContinuation =
            continuationSource.isEmpty
            ? "break"
            : continuationSource

        let source = """
            switch \(bind.expression.trimmedDescription) {
            case .success(\(successPattern)):
            \(successContinuation)
            case .failure(let error):
            return .failure(error)
            }
            """

        let statement = StmtSyntax(stringLiteral: source)
        return CodeBlockItemSyntax(item: .stmt(statement))
    }

    private final class NestedBlockRewriter: SyntaxRewriter {
        override func visit(_ node: CodeBlockSyntax) -> CodeBlockSyntax {
            node.with(\.statements, DoMacro.transform(node.statements, liftFinalExpression: false))
        }

        override func visit(_ node: SwitchCaseSyntax) -> SwitchCaseSyntax {
            node.with(\.statements, DoMacro.transform(node.statements, liftFinalExpression: false))
        }

        override func visit(_ node: ClosureExprSyntax) -> ExprSyntax {
            ExprSyntax(node)
        }

        override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
            DeclSyntax(node)
        }
    }
}

public struct BindMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        throw BindMacroError()
    }
}

private struct BindMacroError: Error, CustomStringConvertible {
    var description: String {
        "#bind may only be used inside a @Do function body"
    }
}
