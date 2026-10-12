//
//  DefaultKeyMacro.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct DefaultKeyMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self),
            variable.bindings.count == 1,
            let binding = variable.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
            let annotation = binding.typeAnnotation
        else {
            throw DiagnosticError("@DefaultKey can only be attached to one typed property")
        }

        guard binding.initializer == nil else {
            throw DiagnosticError("@DefaultKey properties cannot have an initializer")
        }

        guard binding.accessorBlock == nil else {
            throw DiagnosticError("@DefaultKey properties cannot have an accessorBlock")
        }

        let propertyName = identifier.identifier.text
        let key = try parseKey(from: node) ?? propertyName
        let type = annotation.type.trimmedDescription
        let access = try AccessStrategy(type: type)
        let receiver = isInsideDefaultsScope(context) ? "_unsafeDefaults." : ""

        let getter: AccessorDeclSyntax = """
            get {
                \(raw: access.getterExpression(key: key, receiver: receiver))
            }
            """

        let setter: AccessorDeclSyntax =
            isInsideDefaultsScope(context)
            ? """
            nonmutating set {
                \(raw: access.setterExpression(key: key, receiver: receiver))
            }
            """
            : """
            set {
                \(raw: access.setterExpression(key: key, receiver: receiver))
            }
            """

        return [getter, setter]
    }

    private static func isInsideDefaultsScope(_ context: some MacroExpansionContext) -> Bool {
        context.lexicalContext.contains { syntax in
            guard let declaration = syntax.as(StructDeclSyntax.self) else { return false }
            return declaration.attributes.contains { element in
                guard case .attribute(let attribute) = element else { return false }
                return attribute.attributeName.trimmedDescription == "Defaults"
            }
        }
    }

    private static func parseKey(from node: AttributeSyntax) throws -> String? {
        guard let arguments = node.arguments else { return nil }
        guard case .argumentList(let list) = arguments else {
            throw DiagnosticError("@DefaultKey expects a string literal")
        }
        guard let first = list.first else { return nil }
        guard list.count == 1,
            first.label == nil,
            let literal = first.expression.as(StringLiteralExprSyntax.self),
            literal.segments.count == 1,
            let segment = literal.segments.first?.as(StringSegmentSyntax.self)
        else {
            throw DiagnosticError("@DefaultKey expects a string literal")
        }
        return segment.content.text
    }
}

private enum AccessStrategy {
    case bool, int, double, float
    case string, data, date, url, array, dictionary

    init(type: String) throws {
        switch type.filter { !$0.isWhitespace } {
        case "Bool": self = .bool
        case "Int": self = .int
        case "Double": self = .double
        case "Float": self = .float
        case "String?", "Optional<String>": self = .string
        case "Data?", "Optional<Data>": self = .data
        case "Date?", "Optional<Date>": self = .date
        case "URL?", "Optional<URL>": self = .url
        case "[Any]?", "Optional<[Any]>": self = .array
        case "[String:Any]?", "Optional<[String:Any]>": self = .dictionary
        default:
            throw DiagnosticError("@DefaultKey does not support type '\(type)'")
        }
    }

    func getterExpression(key: String, receiver: String) -> String {
        let quoted = key.debugDescription
        switch self {
        case .bool: return "return \(receiver)bool(forKey: \(quoted))"
        case .int: return "return \(receiver)integer(forKey: \(quoted))"
        case .double: return "return \(receiver)double(forKey: \(quoted))"
        case .float: return "return \(receiver)float(forKey: \(quoted))"
        case .string: return "return \(receiver)string(forKey: \(quoted))"
        case .data: return "return \(receiver)data(forKey: \(quoted))"
        case .date: return "return \(receiver)object(forKey: \(quoted)) as? Date"
        case .url: return "return \(receiver)url(forKey: \(quoted))"
        case .array: return "return \(receiver)array(forKey: \(quoted))"
        case .dictionary: return "return \(receiver)dictionary(forKey: \(quoted))"
        }
    }

    func setterExpression(key: String, receiver: String) -> String {
        let quoted = key.debugDescription
        switch self {
        case .bool, .int, .double, .float:
            return "\(receiver)set(newValue, forKey: \(quoted))"
        case .string, .data, .date, .url, .array, .dictionary:
            return
                "if let newValue { \(receiver)set(newValue, forKey: \(quoted)) } else { \(receiver)removeObject(forKey: \(quoted)) }"
        }
    }
}

private struct DiagnosticError: Error, DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "RacrosMacro", id: "invalid")
    let severity: DiagnosticSeverity = .error

    init(_ message: String) { self.message = message }
}
