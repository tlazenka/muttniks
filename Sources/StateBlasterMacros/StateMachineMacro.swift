//
//  StateMachineMacro.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SwiftUIPresentationMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}

public struct ScreenMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}

public struct MachineStateMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

public struct StateMachineMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError("@StateMachine can only be attached to an enum")
        }

        let options = try parseOptions(from: node)
        let states = try parseStates(from: enumDecl)
        try validate(states)

        let enumName = enumDecl.name.text
        let machineName = "\(enumName)Machine"
        let access = accessLevel(of: enumDecl)

        let presentation = try parsePresentation(from: enumDecl, states: states)
        let swiftUIPresentation = enumDecl.attributes.compactMap { $0.as(AttributeSyntax.self) }.contains {
            $0.attributeName.trimmedDescription == "SwiftUIPresentation"
        }
        return [
            DeclSyntax(
                stringLiteral: generateMachine(
                    named: machineName,
                    states: states,
                    access: access,
                    mode: options.mode,
                    screens: presentation,
                    swiftUIPresentation: swiftUIPresentation
                )
            )
        ]
    }
}

enum Mode: Equatable {
    case witness
    case transitionAuthority
    case scopedStateAuthority
    case stateAuthority

    var isNoncopyable: Bool { self != .witness }
}

struct Options {
    var mode: Mode = .witness
}

struct StateDescription {
    let caseName: String
    let typeName: String
    let fields: [Field]
    let isInitial: Bool
    let transitions: [String]
    let back: String?

    var isTerminal: Bool { transitions.isEmpty }
}

struct Field {
    let name: String
    let type: String
}

struct ScreenFieldDescription { let name: String; let label: String; let contentType: String? }
struct ScreenActionDescription { let name: String; let title: String; let isAsync: Bool; let enabledWhen: String }
struct ScreenDescription {
    let title: String
    let message: String
    let systemImage: String
    let kind: String
    let fields: [ScreenFieldDescription]
    let actions: [ScreenActionDescription]
    let visibleWhen: String
    let fallback: String?
}

struct MacroError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func parsePresentation(
    from enumDecl: EnumDeclSyntax,
    states: [StateDescription]
) throws -> [String: ScreenDescription]? {
    var result: [String: ScreenDescription] = [:]
    var sawScreen = false

    for member in enumDecl.memberBlock.members {
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self),
            caseDecl.elements.count == 1,
            let element = caseDecl.elements.first
        else { continue }
        guard
            let attribute = caseDecl.attributes.compactMap({ $0.as(AttributeSyntax.self) }).first(where: {
                $0.attributeName.trimmedDescription == "Screen"
            })
        else { continue }

        sawScreen = true
        guard case .argumentList(let arguments) = attribute.arguments else {
            throw MacroError("@Screen requires labeled arguments")
        }
        var title: String?
        var message: String?
        var systemImage: String?
        var kind: String?
        var visibleWhen = ".always"
        var fallback: String?
        var fields: [ScreenFieldDescription] = []
        var actions: [ScreenActionDescription] = []
        for argument in arguments {
            let label = argument.label?.text
            let expression = argument.expression.trimmedDescription
            switch label {
            case "title": title = try stringLiteral(expression, label: "title")
            case "message": message = try stringLiteral(expression, label: "message")
            case "systemImage": systemImage = try stringLiteral(expression, label: "systemImage")
            case "kind":
                kind = expression.replacingOccurrences(of: "ScreenKind.", with: "").replacingOccurrences(
                    of: ".",
                    with: ""
                )
            case "fields": fields = try parseScreenFields(expression)
            case "actions": actions = try parseScreenActions(expression)
            case "visibleWhen": visibleWhen = try parseCondition(expression)
            case "fallback":
                fallback = expression.replacingOccurrences(of: "ScreenKind.", with: "").replacingOccurrences(
                    of: ".",
                    with: ""
                )
            default: break
            }
        }
        guard let title, let message, let systemImage, let kind else {
            throw MacroError("@Screen requires title, message, systemImage, and kind")
        }
        result[element.name.text] = .init(
            title: title,
            message: message,
            systemImage: systemImage,
            kind: kind,
            fields: fields,
            actions: actions,
            visibleWhen: visibleWhen,
            fallback: fallback
        )
    }

    guard sawScreen else { return nil }
    for state in states where result[state.caseName] == nil {
        throw MacroError(
            "State `\(state.caseName)` is missing @Screen metadata while presentation generation is enabled"
        )
    }
    return result
}

func parseScreenFields(_ expression: String) throws -> [ScreenFieldDescription] {
    let pattern = #"\.text\(\s*\"([^\"]+)\"\s*,\s*label:\s*\"([^\"]+)\"(?:\s*,\s*contentType:\s*\"([^\"]+)\")?\s*\)"#
    let regex = try NSRegularExpression(pattern: pattern)
    let ns = expression as NSString
    return regex.matches(in: expression, range: NSRange(location: 0, length: ns.length)).map { match in
        func group(_ index: Int) -> String? {
            let r = match.range(at: index); return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        return .init(name: group(1)!, label: group(2)!, contentType: group(3))
    }
}

func parseScreenActions(_ expression: String) throws -> [ScreenActionDescription] {
    let pattern =
        #"\.(sync|async)\(\s*\"([^\"]+)\"\s*,\s*title:\s*\"([^\"]+)\"(?:\s*,\s*enabledWhen:\s*(.+?))?\s*\)(?=\s*(?:,|\]))"#
    let regex = try NSRegularExpression(pattern: pattern)
    let ns = expression as NSString
    return try regex.matches(in: expression, range: NSRange(location: 0, length: ns.length)).map { match in
        func group(_ index: Int) -> String? {
            let r = match.range(at: index); return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        return .init(
            name: group(2)!,
            title: group(3)!,
            isAsync: group(1) == "async",
            enabledWhen: try parseCondition(group(4) ?? ".always")
        )
    }
}

func parseCondition(_ expression: String) throws -> String {
    let e = expression.trimmingCharacters(in: .whitespacesAndNewlines)
    if e == ".always" || e == "ScreenCondition.always" { return ".always" }
    for (name, emitted) in [("flag", "flag"), ("nonEmpty", "nonEmpty")] {
        let pattern = #"^(?:ScreenCondition)?\.?"# + name + #"\(\s*\"([^\"]+)\"\s*\)$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
            let m = regex.firstMatch(in: e, range: NSRange(e.startIndex..., in: e)),
            let r = Range(m.range(at: 1), in: e)
        {
            return ".\(emitted)(\(swiftString(String(e[r]))))"
        }
    }
    if e.hasPrefix(".not(") && e.hasSuffix(")") {
        return ".not(\(try parseCondition(String(e.dropFirst(5).dropLast()))))"
    }
    for op in ["all", "any"] where e.hasPrefix(".\(op)([") && e.hasSuffix("])") {
        let inner = String(e.dropFirst(op.count + 3).dropLast(2))
        let parts = splitTopLevel(inner)
        return ".\(op)([\(try parts.map(parseCondition).joined(separator: ", "))])"
    }
    throw MacroError("Unsupported ScreenCondition `\(e)`")
}

func splitTopLevel(_ value: String) -> [String] {
    var depth = 0
    var quoted = false
    var current = ""
    var result: [String] = []
    for ch in value {
        if ch == "\"" { quoted.toggle() }
        if !quoted { if ch == "(" || ch == "[" { depth += 1 }; if ch == ")" || ch == "]" { depth -= 1 } }
        if ch == "," && depth == 0 && !quoted { result.append(current); current = "" } else { current.append(ch) }
    }
    if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(current) }
    return result
}

func stringLiteral(_ expression: String, label: String) throws -> String {
    guard expression.count >= 2, expression.first == "\"", expression.last == "\"" else {
        throw MacroError("@Screen \(label): must be a string literal")
    }
    return String(expression.dropFirst().dropLast())
}

func swiftString(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
}

func generatePresentationMembers(
    states: [StateDescription],
    screens: [String: ScreenDescription],
    access: String
) -> String {
    let cases = states.map { "    case \($0.caseName)" }.joined(separator: "\n")
    let kinds = Array(Set(states.compactMap { screens[$0.caseName]?.kind })).sorted().map { "    case \($0)" }.joined(
        separator: "\n"
    )
    let descriptors = states.map { state -> String in
        let screen = screens[state.caseName]!
        let transitions = state.transitions.map { ".\($0)" }.joined(separator: ", ")
        let back = state.back.map { ".\($0)" } ?? "nil"
        let fields = screen.fields.map {
            ".init(name: \(swiftString($0.name)), label: \(swiftString($0.label)), contentType: \($0.contentType.map(swiftString) ?? "nil"))"
        }.joined(separator: ", ")
        let actions = screen.actions.map {
            ".init(name: \(swiftString($0.name)), title: \(swiftString($0.title)), isAsync: \($0.isAsync), enabledWhen: \($0.enabledWhen))"
        }.joined(separator: ", ")
        let fallback = screen.fallback.map { ".\($0)" } ?? "nil"
        return
            "    .init(state: .\(state.caseName), title: \(swiftString(screen.title)), message: \(swiftString(screen.message)), systemImage: \(swiftString(screen.systemImage)), kind: .\(screen.kind), fields: [\(fields)], actions: [\(actions)], visibleWhen: \(screen.visibleWhen), fallback: \(fallback), transitions: [\(transitions)], back: \(back))"
    }.joined(separator: ",\n")
    let accessPrefix = access == "internal" ? "" : "\(access) "
    let allFields = states.flatMap { screens[$0.caseName]?.fields ?? [] }
    let uniqueFields = Dictionary(grouping: allFields, by: \.name).values.compactMap(\.first).sorted {
        $0.name < $1.name
    }
    let allActions = states.flatMap { screens[$0.caseName]?.actions ?? [] }
    let uniqueActions = Dictionary(grouping: allActions, by: \.name).values.compactMap(\.first).sorted {
        $0.name < $1.name
    }
    let conditionTexts = states.flatMap { state -> [String] in
        guard let screen = screens[state.caseName] else { return [] }
        return [screen.visibleWhen] + screen.actions.map(\.enabledWhen)
    }
    let flagPattern = try! NSRegularExpression(pattern: #"\.flag\("([^"]+)"\)"#)
    var flags = Set<String>()
    for text in conditionTexts {
        let ns = text as NSString;
        for m in flagPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            flags.insert(ns.substring(with: m.range(at: 1)))
        }
    }
    let modelRequirements =
        (uniqueFields.map { "        var \($0.name): String { get set }" }
        + flags.sorted().map { "        var \($0): Bool { get }" }
        + uniqueActions.map { "        func \($0.name)()\($0.isAsync ? " async" : "")" }).joined(separator: "\n")

    return """
        \(accessPrefix)enum Screen: String, CaseIterable, Hashable, Sendable {
        \(cases)
        }

        \(accessPrefix)enum ScreenKind: String, Sendable {
        \(kinds)
        }

        \(accessPrefix)struct ScreenDescriptor: Sendable, Equatable {
            \(accessPrefix)let state: Screen
            \(accessPrefix)let title: String
            \(accessPrefix)let message: String
            \(accessPrefix)let systemImage: String
            \(accessPrefix)let kind: ScreenKind
            \(accessPrefix)struct Field: Sendable, Equatable { \(accessPrefix)let name: String; \(accessPrefix)let label: String; \(accessPrefix)let contentType: String? }
            \(accessPrefix)indirect enum Condition: Sendable, Equatable { case always; case flag(String); case nonEmpty(String); case not(Condition); case all([Condition]); case any([Condition]) }
            \(accessPrefix)struct Action: Sendable, Equatable { \(accessPrefix)let name: String; \(accessPrefix)let title: String; \(accessPrefix)let isAsync: Bool; \(accessPrefix)let enabledWhen: Condition }
            \(accessPrefix)let fields: [Field]
            \(accessPrefix)let actions: [Action]
            \(accessPrefix)let visibleWhen: Condition
            \(accessPrefix)let fallback: ScreenKind?
            \(accessPrefix)var action: String? { actions.first?.title }
            \(accessPrefix)let transitions: [Screen]
            \(accessPrefix)let back: Screen?
            \(accessPrefix)init(state: Screen, title: String, message: String, systemImage: String, kind: ScreenKind, fields: [Field], actions: [Action], visibleWhen: Condition, fallback: ScreenKind?, transitions: [Screen], back: Screen?) {
                self.state = state; self.title = title; self.message = message; self.systemImage = systemImage; self.kind = kind; self.fields = fields; self.actions = actions; self.visibleWhen = visibleWhen; self.fallback = fallback; self.transitions = transitions; self.back = back
            }
        }

        \(accessPrefix)static let screens: [ScreenDescriptor] = [
        \(descriptors)
        ]

        @MainActor
        \(accessPrefix)protocol PresentationModel: AnyObject {
            var screen: Screen { get }
            var navigationPath: [NavigationEntry] { get }
            func setNavigationPath(_ proposed: [NavigationEntry])
            var presentationErrorMessage: String? { get }
        \(modelRequirements)
        }

        \(accessPrefix)struct NavigationEntry: Hashable, Sendable {
            \(accessPrefix)let id: UUID
            \(accessPrefix)let screen: Screen
            \(accessPrefix)init(id: UUID = UUID(), screen: Screen) { self.id = id; self.screen = screen }
        }
        """
}

func generateSwiftUIPresentation(
    states: [StateDescription],
    screens: [String: ScreenDescription],
    access: String
) -> String {
    let accessPrefix = access == "internal" ? "" : "\(access) "
    let fields = Dictionary(grouping: states.flatMap { screens[$0.caseName]?.fields ?? [] }, by: \.name).values
        .compactMap(\.first).sorted { $0.name < $1.name }
    let actions = Dictionary(grouping: states.flatMap { screens[$0.caseName]?.actions ?? [] }, by: \.name).values
        .compactMap(\.first).sorted { $0.name < $1.name }
    let conditionTexts = states.flatMap { state -> [String] in
        guard let screen = screens[state.caseName] else { return [] }
        return [screen.visibleWhen] + screen.actions.map(\.enabledWhen)
    }
    let flagPattern = try! NSRegularExpression(pattern: #"\.flag\(\"([^\"]+)\"\)"#)
    var flags = Set<String>()
    for text in conditionTexts {
        let ns = text as NSString;
        for m in flagPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            flags.insert(ns.substring(with: m.range(at: 1)))
        }
    }

    let fieldBindingCases = fields.map {
        "case \(swiftString($0.name)): return SwiftUI.Binding(get: { model.\($0.name) }, set: { model.\($0.name) = $0 })"
    }.joined(separator: "\n                    ")
    let valueCases = fields.map { "case \(swiftString($0.name)): return model.\($0.name)" }.joined(
        separator: "\n                    "
    )
    let flagCases = flags.sorted().map { "case \(swiftString($0)): return model.\($0)" }.joined(
        separator: "\n                    "
    )
    let actionCases = actions.map { action in
        if action.isAsync { return "case \(swiftString(action.name)): Task { await model.\(action.name)() }" }
        return "case \(swiftString(action.name)): model.\(action.name)()"
    }.joined(separator: "\n                    ")

    return """
        @MainActor
        \(accessPrefix)struct PresentationView<Model: PresentationModel & Observation.Observable>: SwiftUI.View {
            @SwiftUI.Bindable private var model: Model
            \(accessPrefix)init(model: Model) { self.model = model }

            \(accessPrefix)var body: some SwiftUI.View {
                SwiftUI.NavigationStack(path: SwiftUI.Binding(get: { model.navigationPath }, set: { model.setNavigationPath($0) })) {
                    ScreenView(screen: .initializing, model: model)
                        .navigationDestination(for: NavigationEntry.self) { entry in ScreenView(screen: entry.screen, model: model) }
                }
            }
        }

        @MainActor
        private struct ScreenView<Model: PresentationModel & Observation.Observable>: SwiftUI.View {
            let screen: Screen
            @SwiftUI.Bindable var model: Model
            var body: some SwiftUI.View {
                let d = Self.descriptor(screen)
                FormShell(descriptor: d, message: screen == .error ? model.presentationErrorMessage : nil) {
                    if Conditions.evaluate(d.visibleWhen, model: model) {
                        ScreenBody(kind: d.kind, descriptor: d, model: model)
                    } else if let fallback = d.fallback {
                        ScreenBody(kind: fallback, descriptor: d, model: model)
                    }
                }
                .navigationTitle(d.title)
            }
            private static func descriptor(_ screen: Screen) -> ScreenDescriptor { screens.first { $0.state == screen }! }
        }

        @MainActor
        private struct ScreenBody<Model: PresentationModel & Observation.Observable>: SwiftUI.View {
            let kind: ScreenKind
            let descriptor: ScreenDescriptor
            @SwiftUI.Bindable var model: Model
            @SwiftUI.ViewBuilder var body: some SwiftUI.View {
                switch kind {
                case .form:
                    Fields(descriptor: descriptor, model: model)
                    Actions(descriptor: descriptor, model: model)
                case .progress: SwiftUI.ProgressView()
                case .error, .help: Actions(descriptor: descriptor, model: model)
                case .success: SwiftUI.Label(descriptor.title, systemImage: descriptor.systemImage)
                }
            }
        }

        @MainActor
        private enum Conditions {
            static func evaluate<Model: PresentationModel>(_ condition: ScreenDescriptor.Condition, model: Model) -> Bool {
                switch condition {
                case .always: return true
                case .flag(let name):
                    switch name {
                        \(flagCases)
                    default: preconditionFailure("Unknown generated flag: \\(name)")
                    }
                case .nonEmpty(let name): return !value(name, model: model).isEmpty
                case .not(let c): return !evaluate(c, model: model)
                case .all(let cs): return cs.allSatisfy { evaluate($0, model: model) }
                case .any(let cs): return cs.contains { evaluate($0, model: model) }
                }
            }
            private static func value<Model: PresentationModel>(_ name: String, model: Model) -> String {
                switch name {
                    \(valueCases)
                default: preconditionFailure("Unknown generated value: \\(name)")
                }
            }
        }

        @MainActor
        private struct Fields<Model: PresentationModel & Observation.Observable>: SwiftUI.View {
            let descriptor: ScreenDescriptor
            @SwiftUI.Bindable var model: Model
            var body: some SwiftUI.View {
                SwiftUI.ForEach(descriptor.fields, id: \\.name) { field in
                    SwiftUI.TextField(field.label, text: binding(for: field)).textFieldStyle(.roundedBorder)
                }
            }
            private func binding(for field: ScreenDescriptor.Field) -> SwiftUI.Binding<String> {
                switch field.name {
                    \(fieldBindingCases)
                default: preconditionFailure("Unknown generated field: \\(field.name)")
                }
            }
        }

        @MainActor
        private struct Actions<Model: PresentationModel & Observation.Observable>: SwiftUI.View {
            let descriptor: ScreenDescriptor
            @SwiftUI.Bindable var model: Model
            var body: some SwiftUI.View {
                SwiftUI.ForEach(descriptor.actions, id: \\.name) { action in
                    SwiftUI.Button(action.title) { perform(action) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!Conditions.evaluate(action.enabledWhen, model: model))
                }
            }
            private func perform(_ action: ScreenDescriptor.Action) {
                switch action.name {
                    \(actionCases)
                default: preconditionFailure("Unknown generated action: \\(action.name)")
                }
            }
        }

        private struct FormShell<Content: SwiftUI.View>: SwiftUI.View {
            let descriptor: ScreenDescriptor
            let message: String?
            @SwiftUI.ViewBuilder let content: Content
            init(descriptor: ScreenDescriptor, message: String?, @SwiftUI.ViewBuilder content: () -> Content) { self.descriptor = descriptor; self.message = message; self.content = content() }
            var body: some SwiftUI.View {
                SwiftUI.VStack(alignment: .leading, spacing: 20) {
                    SwiftUI.Spacer()
                    SwiftUI.Image(systemName: descriptor.systemImage).font(.system(size: 48, weight: .semibold))
                    SwiftUI.Text(descriptor.title).font(.largeTitle.bold())
                    SwiftUI.Text(message ?? descriptor.message).font(.title3).foregroundStyle(.secondary)
                    content
                    SwiftUI.Spacer()
                }.padding(28).frame(maxWidth: 560)
            }
        }
        """
}

func parseOptions(from attribute: AttributeSyntax) throws -> Options {
    var options = Options()
    guard let arguments = attribute.arguments else { return options }
    guard case .argumentList(let argumentList) = arguments else {
        throw MacroError("@StateMachine only accepts labeled arguments")
    }

    for argument in argumentList {
        switch argument.label?.text {
        case "mode":
            switch argument.expression.trimmedDescription {
            case ".witness", "StateMachineMode.witness":
                options.mode = .witness
            case ".transitionAuthority", "StateMachineMode.transitionAuthority":
                options.mode = .transitionAuthority
            case ".scopedStateAuthority", "StateMachineMode.scopedStateAuthority":
                options.mode = .scopedStateAuthority
            case ".stateAuthority", "StateMachineMode.stateAuthority":
                options.mode = .stateAuthority
            default:
                throw MacroError(
                    "@StateMachine mode: must be .witness, .transitionAuthority, .scopedStateAuthority, or .stateAuthority"
                )
            }

        case nil:
            throw MacroError("@StateMachine arguments must be labeled")

        default:
            throw MacroError("Unknown @StateMachine argument `\(argument.label?.text ?? "")`")
        }
    }

    return options
}

func accessLevel(of declaration: EnumDeclSyntax) -> String {
    for modifier in declaration.modifiers {
        switch modifier.name.text {
        case "public", "package", "internal", "fileprivate", "private":
            return modifier.name.text
        default:
            continue
        }
    }
    return "internal"
}

func accessLevel(of declaration: ClassDeclSyntax) -> String {
    for modifier in declaration.modifiers {
        switch modifier.name.text {
        case "public", "package", "internal", "fileprivate", "private":
            return modifier.name.text
        default:
            continue
        }
    }
    return "internal"
}

func parseStates(from enumDecl: EnumDeclSyntax) throws -> [StateDescription] {
    var states: [StateDescription] = []

    for member in enumDecl.memberBlock.members {
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
        guard caseDecl.elements.count == 1, let element = caseDecl.elements.first else {
            throw MacroError("@StateMachine requires one enum case per `case` declaration")
        }

        let metadata = try parseMetadata(from: caseDecl)
        var fields: [Field] = []

        if let parameterClause = element.parameterClause {
            for parameter in parameterClause.parameters {
                guard let firstName = parameter.firstName else {
                    throw MacroError(
                        "State `\(element.name.text)` has an unlabeled associated value; all values must be labeled"
                    )
                }
                if parameter.secondName != nil {
                    throw MacroError(
                        "State `\(element.name.text)` uses a two-part associated-value label; use `name: Type`"
                    )
                }
                let fieldName = firstName.text
                guard fieldName != "_" else {
                    throw MacroError(
                        "State `\(element.name.text)` has an unlabeled associated value; all values must be labeled"
                    )
                }
                fields.append(Field(name: fieldName, type: parameter.type.trimmedDescription))
            }
        }

        states.append(
            StateDescription(
                caseName: element.name.text,
                typeName: generatedTypeName(for: element.name.text),
                fields: fields,
                isInitial: metadata.initial,
                transitions: metadata.transitions,
                back: metadata.back
            )
        )
    }

    guard !states.isEmpty else {
        throw MacroError("@StateMachine enum must contain at least one enum case")
    }
    return states
}

func parseMetadata(
    from caseDecl: EnumCaseDeclSyntax
) throws -> (initial: Bool, transitions: [String], back: String?) {
    var stateAttribute: AttributeSyntax?
    for attributeElement in caseDecl.attributes {
        guard let attribute = attributeElement.as(AttributeSyntax.self) else { continue }
        if attribute.attributeName.trimmedDescription == "MachineState" {
            stateAttribute = attribute
            break
        }
    }

    guard let stateAttribute else {
        let name = caseDecl.elements.first?.name.text ?? "<unknown>"
        throw MacroError("State `\(name)` is missing @MachineState")
    }

    var initial = false
    var transitions: [String] = []
    var back: String?
    guard let arguments = stateAttribute.arguments else { return (initial, transitions, back) }
    guard case .argumentList(let argumentList) = arguments else {
        throw MacroError("@MachineState only accepts labeled arguments")
    }

    for argument in argumentList {
        switch argument.label?.text {
        case "initial":
            let value = argument.expression.trimmedDescription
            guard value == "true" || value == "false" else {
                throw MacroError("@MachineState initial: must be a Boolean literal")
            }
            initial = value == "true"

        case "transitions":
            guard let array = argument.expression.as(ArrayExprSyntax.self) else {
                throw MacroError("@MachineState transitions: must be an array of string literals")
            }
            transitions = try array.elements.map { element in
                guard element.expression.is(StringLiteralExprSyntax.self) else {
                    throw MacroError("@MachineState transitions: must contain only string literals")
                }
                let text = element.expression.trimmedDescription
                guard text.count >= 2, text.first == "\"", text.last == "\"" else {
                    throw MacroError("@MachineState transitions: must contain simple string literals")
                }
                return String(text.dropFirst().dropLast())
            }

        case "back":
            let text = argument.expression.trimmedDescription
            if text == "nil" {
                back = nil
            } else {
                guard text.count >= 2, text.first == "\"", text.last == "\"" else {
                    throw MacroError("@MachineState back: must be a string literal or nil")
                }
                back = String(text.dropFirst().dropLast())
            }

        case nil:
            throw MacroError("@MachineState arguments must be labeled")
        default:
            throw MacroError("Unknown @MachineState argument `\(argument.label?.text ?? "")`")
        }
    }
    return (initial, transitions, back)
}

func validate(_ states: [StateDescription]) throws {
    let names = states.map(\.caseName)
    let nameSet = Set(names)
    guard nameSet.count == names.count else {
        throw MacroError("@StateMachine contains duplicate case names")
    }

    let initialStates = states.filter(\.isInitial)
    guard initialStates.count == 1 else {
        throw MacroError("@StateMachine requires exactly one initial state; found \(initialStates.count)")
    }

    for state in states {
        let fieldNames = state.fields.map(\.name)
        guard Set(fieldNames).count == fieldNames.count else {
            throw MacroError("State `\(state.caseName)` contains duplicate associated-value labels")
        }
        for transition in state.transitions where !nameSet.contains(transition) {
            throw MacroError("State `\(state.caseName)` transitions to unknown state `\(transition)`")
        }
        if let back = state.back, !nameSet.contains(back) {
            throw MacroError("State `\(state.caseName)` navigates back to unknown state `\(back)`")
        }
    }
}

func generateMachine(
    named machineName: String,
    states: [StateDescription],
    access: String,
    mode: Mode,
    screens: [String: ScreenDescription]? = nil,
    swiftUIPresentation: Bool = false
) -> String {
    let memberAccess = access == "private" ? "fileprivate" : access
    let initial = states.first(where: \.isInitial)!
    let kindCases = states.map { "case \($0.caseName)" }.joined(separator: "\n        ")
    let kindSwitch = states.map { "case .\($0.caseName): .\($0.caseName)" }.joined(separator: "\n            ")
    let screenProjection: String
    let presentationMembers: String
    if let screens {
        let projection = states.map { "case .\($0.caseName): .\($0.caseName)" }.joined(separator: "\n                ")
        screenProjection = """

                \(memberAccess) var screen: Screen {
                    switch self {
                    \(projection)
                    }
                }
            """
        presentationMembers =
            generatePresentationMembers(states: states, screens: screens, access: memberAccess)
            + (swiftUIPresentation
                ? "\n\n" + generateSwiftUIPresentation(states: states, screens: screens, access: memberAccess) : "")
    } else {
        screenProjection = ""
        presentationMembers = ""
    }
    let initialSwitch = states.map { "case .\($0.caseName): \($0.isInitial ? "true" : "false")" }.joined(
        separator: "\n            "
    )
    let terminalSwitch = states.map { "case .\($0.caseName): \($0.isTerminal ? "true" : "false")" }.joined(
        separator: "\n            "
    )
    let transitionSwitch = states.map { state in
        let values = state.transitions.map { ".\($0)" }.joined(separator: ", ")
        return "case .\(state.caseName): [\(values)]"
    }.joined(separator: "\n            ")

    let stateDeclarations = states.map {
        generateState($0, allStates: states, access: memberAccess, mode: mode)
    }.joined(separator: "\n\n")
    let runtimeDeclarations = generateRuntime(
        states: states,
        access: memberAccess,
        mode: mode,
        kindSwitch: kindSwitch,
        initialSwitch: initialSwitch,
        terminalSwitch: terminalSwitch,
        transitionSwitch: transitionSwitch
    )
    let startDeclaration = generateStart(for: initial, access: memberAccess)
    let initialStateDeclaration = generateInitialState(for: initial, access: memberAccess, mode: mode)
    let machineDeclaration = generateMachineWrapper(states: states, access: memberAccess, mode: mode)

    let protocolBlock: String
    switch mode {
    case .witness:
        protocolBlock = """
            \(memberAccess) protocol StateToken {}
            \(memberAccess) protocol InitialStateToken: StateToken {}
            \(memberAccess) protocol TerminalStateToken: StateToken {}
            """
    case .transitionAuthority, .scopedStateAuthority, .stateAuthority:
        protocolBlock = """
            \(memberAccess) protocol StateToken: ~Copyable {}
            \(memberAccess) protocol InitialStateToken: StateToken, ~Copyable {}
            \(memberAccess) protocol TerminalStateToken: StateToken, ~Copyable {}
            """
    }

    return """
        \(access) enum \(machineName) {
        \(indent(protocolBlock, by: 4))

            \(memberAccess) enum Kind: String, CaseIterable, Sendable {
                \(kindCases)
        \(screenProjection)
            }

        \(indent(presentationMembers, by: 4))

        \(indent(stateDeclarations, by: 4))

        \(indent(runtimeDeclarations, by: 4))

        \(indent(startDeclaration, by: 4))

        \(indent(initialStateDeclaration, by: 4))

        \(indent(machineDeclaration, by: 4))
        }
        """
}

func generateRuntime(
    states: [StateDescription],
    access: String,
    mode: Mode,
    kindSwitch: String,
    initialSwitch: String,
    terminalSwitch: String,
    transitionSwitch: String
) -> String {
    let screenCases = states.map { state in
        let payload = state.fields.isEmpty ? "" : ", \(parameterList(for: state.fields))"
        return "case \(state.caseName)(StateWitness<\(state.typeName)>\(payload))"
    }.joined(separator: "\n        ")

    let equalitySwitch = states.map { state in
        let ignored = state.fields.map { _ in "_" }.joined(separator: ", ")
        let lhs =
            ignored.isEmpty
            ? ".\(state.caseName)(let lhsWitness)"
            : ".\(state.caseName)(let lhsWitness, \(ignored))"
        let rhs =
            ignored.isEmpty
            ? ".\(state.caseName)(let rhsWitness)"
            : ".\(state.caseName)(let rhsWitness, \(ignored))"
        return "case (\(lhs), \(rhs)): lhsWitness == rhsWitness"
    }.joined(separator: "\n            ")

    let stateDeclaration = """
        \(access) enum State: Equatable {
            \(screenCases)

            \(access) var kind: Kind {
                switch self {
                \(kindSwitch)
                }
            }

            \(access) var isInitial: Bool {
                switch self {
                \(initialSwitch)
                }
            }

            \(access) var isTerminal: Bool {
                switch self {
                \(terminalSwitch)
                }
            }

            \(access) var allowedTransitions: [Kind] {
                switch self {
                \(transitionSwitch)
                }
            }

            \(access) static func == (lhs: Self, rhs: Self) -> Bool {
                switch (lhs, rhs) {
                \(equalitySwitch)
                default: false
                }
            }
        }
        """

    switch mode {
    case .witness:
        return generateWitnessRuntime(states: states, access: access, stateDeclaration: stateDeclaration)
    case .transitionAuthority:
        return generateTransitionAuthorityRuntime(states: states, access: access, stateDeclaration: stateDeclaration)
    case .scopedStateAuthority:
        return generateScopedStateAuthorityRuntime(states: states, access: access, stateDeclaration: stateDeclaration)
    case .stateAuthority:
        return generateStateAuthorityRuntime(states: states, access: access, stateDeclaration: stateDeclaration)
    }
}

func generateInitialState(for state: StateDescription, access: String, mode: Mode) -> String {
    let params = state.fields.isEmpty ? "" : parameterList(for: state.fields)
    let args = state.fields.isEmpty ? "" : argumentList(for: state.fields)
    let signature =
        state.fields.isEmpty
        ? "\(access) static func initialState() -> State"
        : "\(access) static func initialState(\(params)) -> State"
    let startCall = state.fields.isEmpty ? "start()" : "start(\(args))"
    let witnessArgument = mode.isNoncopyable ? "consume initial" : "initial"
    let payloadBindings = state.fields.map {
        "let screen\($0.name.prefix(1).uppercased() + $0.name.dropFirst()) = initial.\($0.name)"
    }.joined(separator: "\n        ")
    let payloadArguments = state.fields.map {
        let local = "screen\($0.name.prefix(1).uppercased() + $0.name.dropFirst())"
        return "\($0.name): \(local)"
    }.joined(separator: ", ")
    let suffix = payloadArguments.isEmpty ? "" : ", \(payloadArguments)"

    return """
        \(signature) {
            let initial = \(startCall)
            \(payloadBindings)
            return .\(state.caseName)(StateWitness(\(witnessArgument))\(suffix))
        }
        """
}

func generateStart(for state: StateDescription, access: String) -> String {
    if state.fields.isEmpty {
        return "\(access) static func start() -> \(state.typeName) {\n            .init()\n        }"
    }
    return
        "\(access) static func start(\(parameterList(for: state.fields))) -> \(state.typeName) {\n            .init(\(argumentList(for: state.fields)))\n        }"
}

func generateState(
    _ state: StateDescription,
    allStates: [StateDescription],
    access: String,
    mode: Mode
) -> String {
    var conformances = ["StateToken"]
    if state.isInitial { conformances.append("InitialStateToken") }
    if state.isTerminal { conformances.append("TerminalStateToken") }
    if mode.isNoncopyable { conformances.append("~Copyable") }

    let properties = state.fields.map { "\(access) let \($0.name): \($0.type)" }.joined(separator: "\n    ")
    let initializer: String
    if state.fields.isEmpty {
        initializer = "fileprivate init() {}"
    } else {
        let assignments = state.fields.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n        ")
        initializer = """
            fileprivate init(\(parameterList(for: state.fields))) {
                \(assignments)
            }
            """
    }

    let constructionTargets = state.transitions + (state.back.map { [$0] } ?? [])
    let transitionMethods = constructionTargets.compactMap { destinationName -> String? in
        guard let destination = allStates.first(where: { $0.caseName == destinationName }) else { return nil }
        return generateTransition(from: state, to: destination, access: access, mode: mode)
    }.joined(separator: "\n\n    ")

    let bodyParts = [
        properties,
        initializer,
        transitionMethods,
    ].filter { !$0.isEmpty }

    return """
        \(access) struct \(state.typeName): \(conformances.joined(separator: ", ")) {
            \(bodyParts.joined(separator: "\n\n    "))
        }
        """
}

func generateTransition(
    from source: StateDescription,
    to destination: StateDescription,
    access: String,
    mode: Mode
) -> String {
    let reusable = Dictionary(uniqueKeysWithValues: source.fields.map { ($0.name, $0.type) })
    let required = destination.fields.filter { reusable[$0.name] != $0.type }
    let modifier = mode.isNoncopyable ? "consuming " : ""
    let signature =
        required.isEmpty
        ? "\(access) \(modifier)func \(destination.caseName)() -> \(destination.typeName)"
        : "\(access) \(modifier)func \(destination.caseName)(\(parameterList(for: required))) -> \(destination.typeName)"

    let arguments = destination.fields.map { field in
        reusable[field.name] == field.type
            ? "\(field.name): self.\(field.name)"
            : "\(field.name): \(field.name)"
    }.joined(separator: ", ")
    let construction =
        destination.fields.isEmpty
        ? "\(destination.typeName)()"
        : "\(destination.typeName)(\(arguments))"

    return """
        \(signature) {
            \(construction)
        }
        """
}

public struct StateMachineModelMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError("@StateMachineModel can only be attached to a class")
        }
        let modelName = classDecl.name.text
        let declaredAccess = accessLevel(of: classDecl)
        let access = declaredAccess == "private" ? "fileprivate" : declaredAccess
        guard let arguments = node.arguments,
            case .argumentList(let list) = arguments,
            let first = list.first
        else {
            throw MacroError("@StateMachineModel requires the source state enum type, for example `MyState.self`")
        }
        let expression = first.expression.trimmedDescription
        guard expression.hasSuffix(".self") else {
            throw MacroError("@StateMachineModel requires a source enum type expression ending in `.self`")
        }
        let stateEnumName = String(expression.dropLast(5))
        guard !stateEnumName.isEmpty else {
            throw MacroError("@StateMachineModel requires a source enum type")
        }
        let machineName = "\(stateEnumName)Machine"
        var stateProperty = "state"
        for argument in list.dropFirst() {
            let text = argument.expression.trimmedDescription
            guard text.count >= 2, text.first == "\"", text.last == "\"" else {
                throw MacroError("@StateMachineModel property names must be string literals")
            }
            let value = String(text.dropFirst().dropLast())
            switch argument.label?.text {
            case "state": stateProperty = value
            default: throw MacroError("Unknown @StateMachineModel argument")
            }
        }

        return [
            DeclSyntax(
                stringLiteral: generateMachineProperty(
                    modelName: modelName,
                    machineName: machineName,
                    stateProperty: stateProperty,
                    access: access
                )
            )
        ]
    }
}

func generateMachineProperty(
    modelName: String,
    machineName: String,
    stateProperty: String,
    access: String
) -> String {
    """
    \(access) var machine: \(machineName).Machine<\(modelName)> {
        \(machineName).Machine(
            owner: self,
            state: \\\(modelName).\(stateProperty)
        )
    }
    """
}

func generateMachineWrapper(
    states: [StateDescription],
    access: String,
    mode: Mode
) -> String {
    switch mode {
    case .witness:
        return generateWitnessMachineWrapper(states: states, access: access)
    case .transitionAuthority:
        return generateTransitionAuthorityMachineWrapper(states: states, access: access)
    case .scopedStateAuthority:
        return generateScopedStateAuthorityMachineWrapper(states: states, access: access)
    case .stateAuthority:
        return generateStateAuthorityMachineWrapper(states: states, access: access)
    }
}

func parameterList(for fields: [Field]) -> String {
    fields.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
}

func argumentList(for fields: [Field]) -> String {
    fields.map { "\($0.name): \($0.name)" }.joined(separator: ", ")
}

func generatedTypeName(for caseName: String) -> String {
    if caseName == "error" { return "ErrorState" }
    guard let first = caseName.first else { return caseName }
    return first.uppercased() + caseName.dropFirst()
}

func indent(_ source: String, by spaces: Int) -> String {
    let prefix = String(repeating: " ", count: spaces)
    return
        source
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { prefix + $0 }
        .joined(separator: "\n")
}
