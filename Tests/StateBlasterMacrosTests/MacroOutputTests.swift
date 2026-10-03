//
//  MacroOutputTests.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/14/26.
//

#if canImport(StateBlasterMacros)
import Testing
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import StateBlasterMacros

private let testMacros: [String: Macro.Type] = [
    "StateMachineModel": StateMachineModelMacro.self
]

private let twoStateFixture = [
    StateDescription(
        caseName: "initial",
        typeName: "Initial",
        fields: [],
        isInitial: true,
        transitions: ["finished"],
        back: nil
    ),
    StateDescription(
        caseName: "finished",
        typeName: "Finished",
        fields: [Field(name: "value", type: "String")],
        isInitial: false,
        transitions: [],
        back: nil
    ),
]

@Test
func witnessMacroOutputContainsCopyableWitnessAndStateAssignment() {
    let output = generateMachine(
        named: "ExampleStateMachine",
        states: twoStateFixture,
        access: "internal",
        mode: .witness
    )

    #expect(output.contains("struct StateWitness<State>: Equatable"))
    #expect(output.contains("struct Machine<Owner: AnyObject>"))
    #expect(output.contains("var state: Transition"))
    #expect(output.contains("static func finished(_ witness: StateWitness<Initial>, value: String) -> Self"))
    #expect(!output.contains("TransitionAuthority<"))
    #expect(!output.contains("StateAuthority<"))
}

@Test
func transitionAuthorityMacroOutputContainsMoveOnlyExactTransitionAuthorityAndStateAssignment() {
    let output = generateMachine(
        named: "ExampleStateMachine",
        states: twoStateFixture,
        access: "internal",
        mode: .transitionAuthority
    )

    #expect(output.contains("struct TransitionAuthority<Source: ~Copyable, Destination: ~Copyable>: ~Copyable"))
    #expect(output.contains("func authorizeFinished("))
    #expect(output.contains("using witness: StateWitness<"))
    #expect(output.contains("using witness: StateWitness<Initial>"))
    #expect(output.contains(") -> TransitionAuthority<Initial, Finished>?"))
    #expect(
        output.contains(
            "static func finished(_ authority: consuming TransitionAuthority<Initial, Finished>, value: String) -> Self"
        )
    )
    #expect(output.contains("var state: Transition"))
    #expect(output.contains("guard let state = witness.take() else { return false }"))
    #expect(output.contains("let next = (consume state).finished(value: value)"))
    #expect(!output.contains("func apply("))
}

@Test
func stateMacroOutputContainsMoveOnlyStateAuthorityAndClosureAccessor() {
    let output = generateMachine(
        named: "ExampleStateMachine",
        states: twoStateFixture,
        access: "internal",
        mode: .scopedStateAuthority
    )

    #expect(output.contains("struct StateAuthority<State: ~Copyable>: ~Copyable"))
    #expect(output.contains("func authorize("))
    #expect(output.contains("using witness: StateWitness<"))
    #expect(output.contains("using witness: StateWitness<Initial>"))
    #expect(output.contains(") -> StateAuthority<Initial>?"))
    #expect(output.contains("func withState<Result>("))
    #expect(output.contains("_ authority: consuming StateAuthority<Initial>"))
    #expect(output.contains("_ body: (consuming Initial) throws -> Result"))
    #expect(output.contains("func finished(value: String, from state: consuming Initial)"))
    #expect(!output.contains("TransitionAuthority<"))
}

@Test
func stateMacroOutputValidatesBeforeExtractionAndChecksClosureExit() {
    let output = generateMachine(
        named: "ExampleStateMachine",
        states: twoStateFixture,
        access: "internal",
        mode: .scopedStateAuthority
    )

    let validation = output.range(of: "guard isCurrentWitness() else { return nil }")
    let extraction = output.range(of: "guard let state = witness.take() else { return nil }")

    #expect(output.contains("func isCurrentWitness() -> Bool"))
    #expect(output.contains("currentWitness == witness"))
    #expect(validation != nil)
    #expect(extraction != nil)
    if let validation, let extraction {
        #expect(validation.lowerBound < extraction.lowerBound)
    }

    #expect(output.contains("defer {"))
    #expect(output.contains("precondition("))
    #expect(output.contains("!isCurrentWitness()"))
    #expect(output.contains("State closure exited without transitioning away from Initial"))
}

@Test
func stateAuthorityMacroOutputReturnsConcreteStateWithoutClosure() {
    let output = generateMachine(
        named: "ExampleStateMachine",
        states: twoStateFixture,
        access: "internal",
        mode: .stateAuthority
    )

    #expect(output.contains("struct StateAuthority<State: ~Copyable>: ~Copyable"))
    #expect(output.contains("func acquire("))
    #expect(output.contains("_ authority: consuming StateAuthority<Initial>"))
    #expect(output.contains(") -> Initial?"))
    #expect(output.contains("currentWitness == witness"))
    #expect(output.contains("return witness.take()"))
    #expect(output.contains("func finished(value: String, from state: consuming Initial)"))
    #expect(!output.contains("withState"))
    #expect(!output.contains("TransitionAuthority<"))
}

@Test
func stateAuthorityMacroOutputValidatesWitnessBeforeExtractingConcreteState() {
    let output = generateMachine(
        named: "ExampleStateMachine",
        states: twoStateFixture,
        access: "internal",
        mode: .stateAuthority
    )

    let validation = output.range(of: "currentWitness == witness")
    let extraction = output.range(of: "return witness.take()")
    #expect(validation != nil)
    #expect(extraction != nil)
    if let validation, let extraction {
        #expect(validation.lowerBound < extraction.lowerBound)
    }
}

@Test
func privateSchemaMacroOutputUsesFileprivateNestedAPI() {
    let output = generateMachine(
        named: "PrivateStateMachine",
        states: twoStateFixture,
        access: "private",
        mode: .transitionAuthority
    )

    #expect(output.contains("private enum PrivateStateMachine"))
    #expect(output.contains("fileprivate struct TransitionAuthority<"))
    #expect(output.contains("fileprivate struct StateWitness<"))
    #expect(output.contains("fileprivate enum State"))
    #expect(output.contains("fileprivate struct Machine<Owner: AnyObject>"))
    #expect(!output.contains("\n    private enum State"))
    #expect(!output.contains("\n    private struct Machine<Owner: AnyObject>"))
}

@Test
func transitionAuthorityMacroOutputValidatesWitnessBeforeConsumingConcreteState() {
    let output = generateMachine(
        named: "ExampleStateMachine",
        states: twoStateFixture,
        access: "internal",
        mode: .transitionAuthority
    )

    let validation = output.range(of: "currentWitness == witness")
    let extraction = output.range(of: "guard let state = witness.take()")

    #expect(validation != nil)
    #expect(extraction != nil)
    if let validation, let extraction {
        #expect(validation.lowerBound < extraction.lowerBound)
    }
}

@Test
func stateMachineModelMacroOutputUsesFileprivateMachineForPrivateModels() {
    assertMacroExpansion(
        """
        @StateMachineModel(PrivateState.self)
        private final class PrivateModel {
            typealias Machine = PrivateStateMachine
            private(set) var state: Machine.State
        }
        """,
        expandedSource: """
            private final class PrivateModel {
                typealias Machine = PrivateStateMachine
                private(set) var state: Machine.State

                fileprivate var machine: PrivateStateMachine.Machine<PrivateModel> {
                    PrivateStateMachine.Machine(
                        owner: self,
                        state: \\PrivateModel.state
                    )
                }
            }
            """,
        macros: testMacros
    )
}
#endif

@Test
func transitionAuthorityGeneratesDistinctBackAuthorization() {
    let states = [
        StateDescription(
            caseName: "first",
            typeName: "First",
            fields: [Field(name: "value", type: "String")],
            isInitial: true,
            transitions: ["second"],
            back: nil
        ),
        StateDescription(
            caseName: "second",
            typeName: "Second",
            fields: [],
            isInitial: false,
            transitions: [],
            back: "first"
        ),
    ]
    let output = generateMachine(named: "BackMachine", states: states, access: "internal", mode: .transitionAuthority)
    #expect(output.contains("func authorizeBack("))
    #expect(output.contains("static func back("))
    #expect(output.contains("case .second: []"))
}

@Test
func presentationMacroOutputContainsScreenSemanticsAndModelContract() {
    let screens: [String: ScreenDescription] = [
        "initial": .init(
            title: "Start",
            message: "Begin",
            systemImage: "play",
            kind: "phoneEntry",
            fields: [.init(name: "phoneNumber", label: "Phone number", contentType: "telephoneNumber")],
            actions: [
                .init(name: "requestCode", title: "Continue", isAsync: true, enabledWhen: ".nonEmpty(\"phoneNumber\")")
            ],
            visibleWhen: ".flag(\"ready\")",
            fallback: "progress"
        ),
        "finished": .init(
            title: "Done",
            message: "Complete",
            systemImage: "checkmark",
            kind: "success",
            fields: [],
            actions: [],
            visibleWhen: ".always",
            fallback: nil
        ),
    ]
    let output = generatePresentationMembers(
        states: twoStateFixture,
        screens: screens,
        access: "public"
    )

    #expect(output.contains("public enum Screen"))
    #expect(output.contains("public struct ScreenDescriptor"))
    #expect(output.contains("public static let screens"))
    #expect(output.contains("public protocol PresentationModel"))
    #expect(output.contains("var phoneNumber: String { get set }"))
    #expect(output.contains("func requestCode() async"))
    #expect(output.contains("var phoneNumber: String { get set }"))
    #expect(output.contains("transitions: [.finished]"))
    #expect(output.contains("var ready: Bool { get }"))
    #expect(output.contains("enabledWhen: .nonEmpty(\"phoneNumber\")"))
    #expect(output.contains("visibleWhen: .flag(\"ready\")"))
    #expect(output.contains("fallback: .progress"))
}

@Test
func swiftUIPresentationIsNestedAndCompilerGenerated() {
    let screens: [String: ScreenDescription] = [
        "initial": .init(
            title: "Start",
            message: "Begin",
            systemImage: "play",
            kind: "form",
            fields: [.init(name: "phoneNumber", label: "Phone", contentType: "telephoneNumber")],
            actions: [
                .init(name: "requestCode", title: "Continue", isAsync: true, enabledWhen: ".nonEmpty(\"phoneNumber\")")
            ],
            visibleWhen: ".always",
            fallback: nil
        ),
        "finished": .init(
            title: "Done",
            message: "Complete",
            systemImage: "checkmark",
            kind: "success",
            fields: [],
            actions: [],
            visibleWhen: ".always",
            fallback: nil
        ),
    ]
    let output = generateMachine(
        named: "DemoMachine",
        states: twoStateFixture,
        access: "public",
        mode: .transitionAuthority,
        screens: screens,
        swiftUIPresentation: true
    )
    #expect(output.contains("struct PresentationView<Model: PresentationModel & Observation.Observable>: SwiftUI.View"))
    #expect(output.contains("SwiftUI.NavigationStack"))
    #expect(output.contains("private enum Conditions"))
    #expect(output.contains("case .always: return true"))
    #expect(output.contains("case .nonEmpty(let name): return !value(name, model: model).isEmpty"))
    #expect(output.contains("case .not(let c): return !evaluate(c, model: model)"))
    #expect(output.contains("case .all(let cs): return cs.allSatisfy { evaluate($0, model: model) }"))
    #expect(output.contains("case .any(let cs): return cs.contains { evaluate($0, model: model) }"))
    #expect(output.contains("case \"phoneNumber\": return SwiftUI.Binding"))
    #expect(output.contains("case \"requestCode\": Task { await model.requestCode() }"))
}
