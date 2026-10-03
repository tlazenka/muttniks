//
//  WitnessModeGenerator.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import Foundation

func generateWitnessRuntime(
    states: [StateDescription],
    access: String,
    stateDeclaration: String
) -> String {
    """
    \(access) struct StateWitness<State>: Equatable {
        fileprivate let owner: _StateMachineValueOwner<State>
        fileprivate init(_ state: State) { owner = _StateMachineValueOwner(state) }

        \(access) static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.owner.matches(rhs.owner)
        }

        fileprivate func stateValue() -> State { owner.value() }
    }

    \(stateDeclaration)
    """
}

func generateWitnessMachineWrapper(
    states: [StateDescription],
    access: String
) -> String {
    let transitionFactories = states.flatMap { source in
        source.transitions.compactMap { name -> String? in
            guard let destination = states.first(where: { $0.caseName == name }) else { return nil }
            return generateWitnessTransitionFactory(from: source, to: destination, access: access)
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

            \(access) struct Transition {
                fileprivate let apply: (inout State) -> Bool
                fileprivate init(apply: @escaping (inout State) -> Bool) { self.apply = apply }

        \(indent(transitionFactories, by: 8))
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

func generateWitnessTransitionFactory(
    from source: StateDescription,
    to destination: StateDescription,
    access: String
) -> String {
    let reusable = Dictionary(uniqueKeysWithValues: source.fields.map { ($0.name, $0.type) })
    let required = destination.fields.filter { reusable[$0.name] != $0.type }
    let witnessParameter = "_ witness: StateWitness<\(source.typeName)>"
    let parameters = required.isEmpty ? witnessParameter : "\(witnessParameter), \(parameterList(for: required))"
    let sourcePayloadPattern =
        source.fields.isEmpty ? "" : ", " + source.fields.map { _ in "_" }.joined(separator: ", ")
    let callArguments = required.isEmpty ? "" : argumentList(for: required)
    let transitionCall =
        required.isEmpty ? "source.\(destination.caseName)()" : "source.\(destination.caseName)(\(callArguments))"
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
            Self { current in
                guard case .\(source.caseName)(let currentWitness\(sourcePayloadPattern)) = current,
                      currentWitness == witness else { return false }
                let source = witness.stateValue()
                let next = \(transitionCall)
                \(payloadBindings)
                current = .\(destination.caseName)(StateWitness(next)\(destinationSuffix))
                return true
            }
        }
        """
}
