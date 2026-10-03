//
//  StateAuthorityModeGenerator.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import Foundation

func generateStateAuthorityRuntime(states: [StateDescription], access: String, stateDeclaration: String) -> String {
    """
    \(access) struct StateAuthority<State: ~Copyable>: ~Copyable {
        fileprivate let witness: StateWitness<State>
        fileprivate init(_ witness: StateWitness<State>) { self.witness = witness }
    }

    \(access) struct StateWitness<State: ~Copyable>: Equatable {
        fileprivate let owner: _StateMachineStateOwner<State>
        fileprivate init(_ state: consuming State) {
            owner = _StateMachineStateOwner(consume state)
        }
        \(access) static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.owner.matches(rhs.owner)
        }
        fileprivate var isAvailable: Bool { owner.isAvailable }
        fileprivate func take() -> State? { owner.take() }
    }

    \(stateDeclaration)
    """
}

func generateStateAuthorityMachineWrapper(states: [StateDescription], access: String) -> String {
    let authorizers = states.filter { !$0.isTerminal }.map { generateStateAuthorityAuthorizer(for: $0, access: access) }
        .joined(separator: "\n\n")
    let acquirers = states.filter { !$0.isTerminal }.map { generateStateAuthorityAcquirer(for: $0, access: access) }
        .joined(separator: "\n\n")
    let transitions = states.flatMap { source in
        source.transitions.compactMap { name -> String? in
            guard let destination = states.first(where: { $0.caseName == name }) else { return nil }
            return generateStateAuthorityMachineTransition(from: source, to: destination, access: access)
        }
    }.joined(separator: "\n\n")
    return """
        \(access) struct Machine<Owner: AnyObject> {
            private let owner: Owner
            private let stateKeyPath: ReferenceWritableKeyPath<Owner, State>
            \(access) init(owner: Owner, state: ReferenceWritableKeyPath<Owner, State>) {
                self.owner = owner
                self.stateKeyPath = state
            }
        \(indent(authorizers, by: 4))
        \(indent(acquirers, by: 4))
        \(indent(transitions, by: 4))
        }
        """
}

func generateStateAuthorityAuthorizer(for state: StateDescription, access: String) -> String {
    let payload = state.fields.isEmpty ? "" : ", " + state.fields.map { _ in "_" }.joined(separator: ", ")
    return """
        \(access) func authorize(
            using witness: StateWitness<\(state.typeName)>
        ) -> StateAuthority<\(state.typeName)>? {
            guard case .\(state.caseName)(let currentWitness\(payload)) = owner[keyPath: stateKeyPath],
                  currentWitness == witness,
                  witness.isAvailable else { return nil }
            return StateAuthority(witness)
        }
        """
}

func generateStateAuthorityAcquirer(for state: StateDescription, access: String) -> String {
    let payload = state.fields.isEmpty ? "" : ", " + state.fields.map { _ in "_" }.joined(separator: ", ")
    return """
        \(access) func acquire(
            _ authority: consuming StateAuthority<\(state.typeName)>
        ) -> \(state.typeName)? {
            let witness = authority.witness
            guard case .\(state.caseName)(let currentWitness\(payload)) = owner[keyPath: stateKeyPath],
                  currentWitness == witness else { return nil }
            return witness.take()
        }
        """
}

func generateStateAuthorityMachineTransition(
    from source: StateDescription,
    to destination: StateDescription,
    access: String
) -> String {
    let reusable = Dictionary(uniqueKeysWithValues: source.fields.map { ($0.name, $0.type) })
    let required = destination.fields.filter { reusable[$0.name] != $0.type }
    let from = "from state: consuming \(source.typeName)"
    let parameters = required.isEmpty ? from : "\(parameterList(for: required)), \(from)"
    let call =
        required.isEmpty
        ? "(consume state).\(destination.caseName)()"
        : "(consume state).\(destination.caseName)(\(argumentList(for: required)))"
    let bindings = destination.fields.map {
        "let screen\($0.name.prefix(1).uppercased() + $0.name.dropFirst()) = next.\($0.name)"
    }.joined(separator: "\n        ")
    let args = destination.fields.map { "\($0.name): screen\($0.name.prefix(1).uppercased() + $0.name.dropFirst())" }
        .joined(separator: ", ")
    let suffix = args.isEmpty ? "" : ", \(args)"
    return """
        \(access) func \(destination.caseName)(\(parameters)) {
            let next = \(call)
            \(bindings)
            let nextWitness = StateWitness<\(destination.typeName)>(consume next)
            owner[keyPath: stateKeyPath] = .\(destination.caseName)(nextWitness\(suffix))
        }
        """
}
