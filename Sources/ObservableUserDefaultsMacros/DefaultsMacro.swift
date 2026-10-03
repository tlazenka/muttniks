//
//  DefaultsMacro.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct DefaultsMacro: MemberMacro, MemberAttributeMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            throw DefaultsDiagnostic("@Defaults can only be attached to a struct")
        }

        let defaultStore = try storeExpression(from: node)
        let access = declaration.modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) }) ? "public " : ""
        let properties = try schemaProperties(in: declaration)

        let keyMembers = properties.map { property in
            "\(access)static let \(property.name) = \(property.key.debugDescription)"
        }.joined(separator: "\n")
        let keyValues = properties.map { "Keys.\($0.name)" }.joined(separator: ", ")
        let registrations = properties.compactMap { property -> String? in
            guard let expression = property.registeredExpression else { return nil }
            return "Keys.\(property.name): \(expression)"
        }.joined(separator: ",\n")
        let registrationLiteral =
            registrations.isEmpty
            ? "[:]"
            : "[\n\(registrations)\n]"

        return [
            "\(raw: access)let _unsafeDefaults: UserDefaults",
            "\(raw: access)init(defaults: UserDefaults = \(raw: defaultStore)) { self._unsafeDefaults = defaults }",
            """
            \(raw: access)enum Keys {
                \(raw: keyMembers)
            }
            """,
            "\(raw: access)static var keys: Set<String> { [\(raw: keyValues)] }",
            "\(raw: access)static var registrationDefaults: [String: Any] { \(raw: registrationLiteral) }",
            "\(raw: access)func register() { _unsafeDefaults.register(defaults: Self.registrationDefaults) }",
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        [try ExtensionDeclSyntax("extension \(type): DefaultsScope {}")]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let variable = member.as(VariableDeclSyntax.self),
            !variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }),
            variable.bindings.count == 1,
            let binding = variable.bindings.first,
            binding.pattern.is(IdentifierPatternSyntax.self),
            binding.typeAnnotation != nil,
            binding.initializer == nil,
            binding.accessorBlock == nil
        else { return [] }

        if variable.attributes.contains(where: { element in
            guard case .attribute(let attr) = element else { return false }
            return attr.attributeName.trimmedDescription == "DefaultKey"
        }) {
            return []
        }

        return [AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("DefaultKey")))]
    }

    private struct SchemaProperty {
        let name: String
        let key: String
        let registeredExpression: String?
    }

    private static func schemaProperties(in declaration: some DeclGroupSyntax) throws -> [SchemaProperty] {
        try declaration.memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                !variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }),
                variable.bindings.count == 1,
                let binding = variable.bindings.first,
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                let type = binding.typeAnnotation?.type.trimmedDescription,
                binding.initializer == nil,
                binding.accessorBlock == nil
            else { return nil }

            let name = identifier.identifier.text
            var key = name
            var registered: String?

            for element in variable.attributes {
                guard case .attribute(let attribute) = element else { continue }
                switch attribute.attributeName.trimmedDescription {
                case "DefaultKey":
                    if let arguments = attribute.arguments,
                        case .argumentList(let list) = arguments,
                        let first = list.first,
                        let literal = first.expression.as(StringLiteralExprSyntax.self),
                        literal.segments.count == 1,
                        let segment = literal.segments.first?.as(StringSegmentSyntax.self)
                    {
                        key = segment.content.text
                    }
                case "Registered":
                    guard let arguments = attribute.arguments,
                        case .argumentList(let list) = arguments,
                        list.count == 1,
                        let first = list.first
                    else {
                        throw DefaultsDiagnostic("@Registered expects one literal value")
                    }
                    let expression = first.expression.trimmedDescription
                    try validateRegistration(expression: expression, propertyType: type)
                    registered = expression
                default:
                    break
                }
            }
            return SchemaProperty(name: name, key: key, registeredExpression: registered)
        }
    }

    private static func validateRegistration(expression: String, propertyType: String) throws {
        let compactType = propertyType.filter { !$0.isWhitespace }
        if expression == "nil" {
            throw DefaultsDiagnostic(
                "@Registered(nil) is not supported"
            )
        }

        let valid: Bool
        if expression == "true" || expression == "false" {
            valid = compactType == "Bool" || compactType == "Bool?" || compactType == "Optional<Bool>"
        } else if expression.hasPrefix("\"") && expression.hasSuffix("\"") {
            valid = ["String", "String?", "Optional<String>"].contains(compactType)
        } else if Double(expression) != nil {
            valid = [
                "Int", "Int?", "Optional<Int>", "Double", "Double?", "Optional<Double>", "Float", "Float?",
                "Optional<Float>",
            ].contains(compactType)
        } else {
            throw DefaultsDiagnostic("@Registered only accepts Bools, numbers, and String literals")
        }

        if !valid {
            throw DefaultsDiagnostic(
                "@Registered value '\(expression)' is incompatible with property type '\(propertyType)'"
            )
        }
    }

    private static func storeExpression(from node: AttributeSyntax) throws -> String {
        guard let arguments = node.arguments else { return "UserDefaults.standard" }
        guard case .argumentList(let list) = arguments, let first = list.first else {
            return "UserDefaults.standard"
        }
        guard list.count == 1 else {
            throw DefaultsDiagnostic("@Defaults accepts at most one store argument")
        }

        let expression = first.expression.trimmedDescription
        if expression == ".standard" { return "UserDefaults.standard" }

        if let call = first.expression.as(FunctionCallExprSyntax.self),
            call.calledExpression.trimmedDescription.hasSuffix(".named"),
            call.arguments.count == 1,
            let arg = call.arguments.first,
            let literal = arg.expression.as(StringLiteralExprSyntax.self),
            literal.segments.count == 1,
            let segment = literal.segments.first?.as(StringSegmentSyntax.self)
        {
            return "UserDefaults(suiteName: \(segment.content.text.debugDescription))!"
        }

        throw DefaultsDiagnostic("@Defaults store must be .standard or .named(\"suite\")")
    }
}

struct DefaultsDiagnostic: Error, DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "RacrosMacro", id: "defaults")
    let severity: DiagnosticSeverity = .error
    init(_ message: String) { self.message = message }
}
