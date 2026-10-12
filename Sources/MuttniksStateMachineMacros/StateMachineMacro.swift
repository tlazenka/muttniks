import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct StateMachineError: DiagnosticMessage {
    let message: String
    var diagnosticID: MessageID { .init(domain: "MuttniksStateMachineMacros", id: "contract") }
    var severity: DiagnosticSeverity { .error }
}

public struct StateMachineContractsMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let e = declaration.as(EnumDeclSyntax.self) else {
            context.diagnose(
                .init(
                    node: Syntax(declaration),
                    message: StateMachineError(message: "@StateMachineContracts can only be attached to an enum")
                )
            )
            return []
        }
        var cases: [String: String?] = [:]
        for member in e.memberBlock.members {
            guard let c = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for element in c.elements {
                let payload = element.parameterClause?.parameters.first?.type.trimmedDescription
                cases[element.name.text] = payload
            }
        }
        var rows: [String] = []
        for member in e.memberBlock.members {
            guard let f = member.decl.as(FunctionDeclSyntax.self) else { continue }
            guard
                let a = f.attributes.compactMap({ $0.as(AttributeSyntax.self) })
                    .first(where: {
                        $0.attributeName.trimmedDescription == "Behavior"
                    })
            else { continue }
            func caseReference(_ label: String) -> (owner: String?, name: String)? {
                guard case .argumentList(let list) = a.arguments else { return nil }
                guard let argument = list.first(where: { $0.label?.text == label }) else { return nil }
                guard let member = argument.expression.as(MemberAccessExprSyntax.self) else { return nil }
                let owner = member.base?.trimmedDescription
                return (owner, member.declName.baseName.text)
            }
            guard let fromRef = caseReference("from") else {
                context.diagnose(
                    .init(
                        node: Syntax(a),
                        message: StateMachineError(
                            message: "@Behavior requires a case reference"
                        )
                    )
                )
                continue
            }
            let toRef = caseReference("to")
            let from = fromRef.name
            let to = toRef?.name
            if let owner = fromRef.owner, owner != e.name.text && owner != "Self" {
                context.diagnose(
                    .init(
                        node: Syntax(a),
                        message: StateMachineError(message: "source state must belong to \(e.name.text)")
                    )
                )
                continue
            }
            if let owner = toRef?.owner, owner != e.name.text && owner != "Self" {
                context.diagnose(
                    .init(
                        node: Syntax(a),
                        message: StateMachineError(message: "destination state must belong to \(e.name.text)")
                    )
                )
                continue
            }
            guard cases.keys.contains(from) else {
                context.diagnose(
                    .init(node: Syntax(a), message: StateMachineError(message: "unknown source state '.\(from)'"))
                )
                continue
            }
            if let to, !cases.keys.contains(to) {
                context.diagnose(
                    .init(node: Syntax(a), message: StateMachineError(message: "unknown destination state '.\(to)'"))
                )
                continue
            }
            let sig = f.signature
            let async = sig.effectSpecifiers?.asyncSpecifier != nil
            let throwing = sig.effectSpecifiers?.throwsClause != nil
            let returnType = sig.returnClause?.type.trimmedDescription
            if let to, let expected = cases[to] ?? nil, let actual = returnType,
                actual != e.name.text && actual != expected
            {
                context.diagnose(
                    .init(
                        node: Syntax(f),
                        message: StateMachineError(
                            message: "behavior '\(f.name.text)' returns \(actual), but '.\(to)' accepts \(expected)"
                        )
                    )
                )
            }
            let destination = to.map { "\"\($0)\"" } ?? "nil"
            rows.append(
                "BehaviorContract(operation: \"\(f.name.text)\", sourceCase: \"\(from)\", destinationCase: \(destination), isAsync: \(async), canThrow: \(throwing))"
            )
        }
        let body = rows.joined(separator: ",\n")
        return [DeclSyntax(stringLiteral: "public static let behaviorContracts: [BehaviorContract] = [\n\(body)\n]")]
    }
}

public struct BehaviorMarkerMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
