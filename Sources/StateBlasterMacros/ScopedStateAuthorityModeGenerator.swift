//
//  ScopedStateAuthorityModeGenerator.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import Foundation

func generateScopedStateAuthorityRuntime(
    states: [StateDescription],
    access: String,
    stateDeclaration: String
) -> String {
    """
    \(access) struct StateAuthority<State: ~Copyable>: ~Copyable {
        fileprivate let witness: StateWitness<State>

        fileprivate init(_ witness: StateWitness<State>) {
            self.witness = witness
        }
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

func generateScopedStateAuthorityMachineWrapper(
    states: [StateDescription],
    access: String
) -> String {
    let authorizers = states.filter { !$0.isTerminal }.map {
        generateScopedStateAuthorityAuthorizer(for: $0, access: access)
    }.joined(separator: "\n\n")
    let accessors = states.filter { !$0.isTerminal }.map {
        generateScopedAccessor(for: $0, access: access)
    }.joined(separator: "\n\n")
    let transitions = states.flatMap { source in
        source.transitions.compactMap { name -> String? in
            guard let destination = states.first(where: { $0.caseName == name }) else { return nil }
            return generateScopedStateAuthorityMachineTransition(from: source, to: destination, access: access)
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

        \(indent(accessors, by: 4))

        \(indent(transitions, by: 4))
        }
        """
}

func generateScopedStateAuthorityAuthorizer(
    for state: StateDescription,
    access: String
) -> String {
    let payloadPattern =
        state.fields.isEmpty
        ? ""
        : ", " + state.fields.map { _ in "_" }.joined(separator: ", ")

    return """
        \(access) func authorize(
            using witness: StateWitness<\(state.typeName)>
        ) -> StateAuthority<\(state.typeName)>? {
            guard case .\(state.caseName)(let currentWitness\(payloadPattern)) = owner[keyPath: stateKeyPath],
                  currentWitness == witness,
                  witness.isAvailable else { return nil }
            return StateAuthority(witness)
        }
        """
}

func generateScopedAccessor(
    for state: StateDescription,
    access: String
) -> String {
    let payloadPattern =
        state.fields.isEmpty
        ? ""
        : ", " + state.fields.map { _ in "_" }.joined(separator: ", ")

    return """
        @discardableResult
        \(access) func withState<Result>(
            _ authority: consuming StateAuthority<\(state.typeName)>,
            _ body: (consuming \(state.typeName)) throws -> Result
        ) rethrows -> Result? {
            let witness = authority.witness

            func isCurrentWitness() -> Bool {
                guard case .\(state.caseName)(let currentWitness\(payloadPattern)) = owner[keyPath: stateKeyPath] else {
                    return false
                }
                return currentWitness == witness
            }

            guard isCurrentWitness() else { return nil }
            guard let state = witness.take() else { return nil }

            defer {
                precondition(
                    !isCurrentWitness(),
                    "State closure exited without transitioning away from \(state.typeName)"
                )
            }

            return try body(consume state)
        }
        """
}

func generateScopedStateAuthorityMachineTransition(
    from source: StateDescription,
    to destination: StateDescription,
    access: String
) -> String {
    let reusable = Dictionary(uniqueKeysWithValues: source.fields.map { ($0.name, $0.type) })
    let required = destination.fields.filter { reusable[$0.name] != $0.type }
    let fromParameter = "from state: consuming \(source.typeName)"
    let parameters = required.isEmpty ? fromParameter : "\(parameterList(for: required)), \(fromParameter)"
    let callArguments = required.isEmpty ? "" : argumentList(for: required)
    let transitionCall =
        required.isEmpty
        ? "(consume state).\(destination.caseName)()"
        : "(consume state).\(destination.caseName)(\(callArguments))"
    let payloadBindings = destination.fields.map {
        let local = "screen\($0.name.prefix(1).uppercased() + $0.name.dropFirst())"
        return "let \(local) = next.\($0.name)"
    }.joined(separator: "\n        ")
    let payloadArguments = destination.fields.map {
        let local = "screen\($0.name.prefix(1).uppercased() + $0.name.dropFirst())"
        return "\($0.name): \(local)"
    }.joined(separator: ", ")
    let screenSuffix = payloadArguments.isEmpty ? "" : ", \(payloadArguments)"

    return """
        \(access) func \(destination.caseName)(\(parameters)) {
            let next = \(transitionCall)
            \(payloadBindings)
            let nextWitness = StateWitness<\(destination.typeName)>(consume next)
            owner[keyPath: stateKeyPath] = .\(destination.caseName)(nextWitness\(screenSuffix))
        }
        """
}
