//
//  TransitionAuthorityModeGenerator.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import Foundation

func generateTransitionAuthorityRuntime(
    states: [StateDescription],
    access: String,
    stateDeclaration: String
) -> String {
    return """
        \(access) struct TransitionAuthority<Source: ~Copyable, Destination: ~Copyable>: ~Copyable {
            fileprivate let witness: StateWitness<Source>

            fileprivate init(_ witness: StateWitness<Source>) {
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

func generateTransitionAuthorityMachineWrapper(
    states: [StateDescription],
    access: String
) -> String {
    let incomingCounts = Dictionary(
        grouping: states.flatMap { source in
            source.transitions.map { ($0, source.caseName) }
        },
        by: { $0.0 }
    ).mapValues(\.count)

    let authorizers = states.flatMap { source in
        source.transitions.compactMap { name -> String? in
            guard let destination = states.first(where: { $0.caseName == name }) else { return nil }
            return generateTransitionAuthorityAuthorizer(
                from: source,
                to: destination,
                disambiguateSource: incomingCounts[destination.caseName, default: 0] > 1,
                access: access
            )
        }
    }.joined(separator: "\n\n")

    let transitionFactories = states.flatMap { source in
        source.transitions.compactMap { name -> String? in
            guard let destination = states.first(where: { $0.caseName == name }) else { return nil }
            return generateTransitionAuthorityTransitionFactory(from: source, to: destination, access: access)
        }
    }.joined(separator: "\n\n")

    let backAuthorizers = states.compactMap { source -> String? in
        guard let back = source.back,
            let destination = states.first(where: { $0.caseName == back })
        else { return nil }
        return generateBackAuthorizer(from: source, to: destination, access: access)
    }.joined(separator: "\n\n")

    let backFactories = states.compactMap { source -> String? in
        guard let back = source.back,
            let destination = states.first(where: { $0.caseName == back })
        else { return nil }
        return generateBackFactory(from: source, to: destination, access: access)
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

        \(indent(backAuthorizers, by: 4))

            \(access) struct Transition {
                fileprivate let apply: (inout State) -> Bool
                fileprivate init(apply: @escaping (inout State) -> Bool) { self.apply = apply }

        \(indent(transitionFactories, by: 8))

        \(indent(backFactories, by: 8))
            }

            \(access) var state: Transition {
                get { Transition { _ in false } }
                nonmutating set {
                    var current = owner[keyPath: stateKeyPath]
                    guard newValue.apply(&current) else { return }
                    owner[keyPath: stateKeyPath] = current
                }
            }
        }
        """
}

private func generateTransitionAuthorityAuthorizer(
    from source: StateDescription,
    to destination: StateDescription,
    disambiguateSource: Bool,
    access: String
) -> String {
    let destinationName = destination.caseName.prefix(1).uppercased() + destination.caseName.dropFirst()
    let methodName =
        disambiguateSource
        ? "authorize\(destinationName)From\(source.typeName)"
        : "authorize\(destinationName)"
    let payloadPattern = source.fields.isEmpty ? "" : ", " + source.fields.map { _ in "_" }.joined(separator: ", ")
    return """
        \(access) func \(methodName)(
            using witness: StateWitness<\(source.typeName)>
        ) -> TransitionAuthority<\(source.typeName), \(destination.typeName)>? {
            guard case .\(source.caseName)(let currentWitness\(payloadPattern)) = owner[keyPath: stateKeyPath],
                  currentWitness == witness,
                  witness.isAvailable else { return nil }
            return TransitionAuthority(witness)
        }
        """
}

private func generateTransitionAuthorityTransitionFactory(
    from source: StateDescription,
    to destination: StateDescription,
    access: String
) -> String {
    let reusable = Dictionary(uniqueKeysWithValues: source.fields.map { ($0.name, $0.type) })
    let required = destination.fields.filter { reusable[$0.name] != $0.type }
    let authorityParameter = "_ authority: consuming TransitionAuthority<\(source.typeName), \(destination.typeName)>"
    let parameters = required.isEmpty ? authorityParameter : "\(authorityParameter), \(parameterList(for: required))"
    let sourcePayloadPattern =
        source.fields.isEmpty ? "" : ", " + source.fields.map { _ in "_" }.joined(separator: ", ")
    let callArguments = required.isEmpty ? "" : argumentList(for: required)
    let payloadBindings = destination.fields.map {
        let local = "next\($0.name.prefix(1).uppercased() + $0.name.dropFirst())"
        return "let \(local) = next.\($0.name)"
    }.joined(separator: "\n                ")
    let payloadArguments = destination.fields.map {
        let local = "next\($0.name.prefix(1).uppercased() + $0.name.dropFirst())"
        return "\($0.name): \(local)"
    }.joined(separator: ", ")
    let destinationSuffix = payloadArguments.isEmpty ? "" : ", \(payloadArguments)"

    return """
        \(access) static func \(destination.caseName)(\(parameters)) -> Self {
            let witness = authority.witness
            return Self { current in
                guard case .\(source.caseName)(let currentWitness\(sourcePayloadPattern)) = current,
                      currentWitness == witness else { return false }
                guard let state = witness.take() else { return false }
                let next = (consume state).\(destination.caseName)(\(callArguments))
                \(payloadBindings)
                current = .\(destination.caseName)(StateWitness(consume next)\(destinationSuffix))
                return true
            }
        }
        """
}

private func generateBackAuthorizer(
    from source: StateDescription,
    to destination: StateDescription,
    access: String
) -> String {
    let payloadPattern = source.fields.isEmpty ? "" : ", " + source.fields.map { _ in "_" }.joined(separator: ", ")
    return """
        \(access) func authorizeBack(
            using witness: StateWitness<\(source.typeName)>
        ) -> TransitionAuthority<\(source.typeName), \(destination.typeName)>? {
            guard case .\(source.caseName)(let currentWitness\(payloadPattern)) = owner[keyPath: stateKeyPath],
                  currentWitness == witness,
                  witness.isAvailable else { return nil }
            return TransitionAuthority(witness)
        }
        """
}

private func generateBackFactory(
    from source: StateDescription,
    to destination: StateDescription,
    access: String
) -> String {
    let reusable = Dictionary(uniqueKeysWithValues: source.fields.map { ($0.name, $0.type) })
    let required = destination.fields.filter { reusable[$0.name] != $0.type }
    let authorityParameter = "_ authority: consuming TransitionAuthority<\(source.typeName), \(destination.typeName)>"
    let parameters = required.isEmpty ? authorityParameter : "\(authorityParameter), \(parameterList(for: required))"
    let sourcePayloadPattern =
        source.fields.isEmpty ? "" : ", " + source.fields.map { _ in "_" }.joined(separator: ", ")
    let callArguments = required.isEmpty ? "" : argumentList(for: required)
    let payloadBindings = destination.fields.map {
        let local = "next\($0.name.prefix(1).uppercased() + $0.name.dropFirst())"
        return "let \(local) = next.\($0.name)"
    }.joined(separator: "\n                ")
    let payloadArguments = destination.fields.map {
        let local = "next\($0.name.prefix(1).uppercased() + $0.name.dropFirst())"
        return "\($0.name): \(local)"
    }.joined(separator: ", ")
    let destinationSuffix = payloadArguments.isEmpty ? "" : ", \(payloadArguments)"

    return """
        \(access) static func back(\(parameters)) -> Self {
            let witness = authority.witness
            return Self { current in
                guard case .\(source.caseName)(let currentWitness\(sourcePayloadPattern)) = current,
                      currentWitness == witness else { return false }
                guard let state = witness.take() else { return false }
                let next = (consume state).\(destination.caseName)(\(callArguments))
                \(payloadBindings)
                current = .\(destination.caseName)(StateWitness(consume next)\(destinationSuffix))
                return true
            }
        }
        """
}
