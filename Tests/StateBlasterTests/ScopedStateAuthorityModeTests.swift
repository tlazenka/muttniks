//
//  ScopedStateAuthorityModeTests.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import StateBlaster
import Testing

@StateMachine(mode: .scopedStateAuthority)
private enum ConcreteStateTestState {
    @MachineState(initial: true, transitions: ["finished"])
    case initial

    @MachineState
    case finished
}

@StateMachineModel(ConcreteStateTestState.self)
private final class ConcreteStateTestModel {
    typealias Machine = ConcreteStateTestStateMachine
    private(set) var state: Machine.State

    init() {
        state = Machine.initialState()
    }
}

@Test
func scopedStateAuthorityModeExposesConcreteStateConsumptionThroughMoveOnlyAuthority() {
    let model = ConcreteStateTestModel()

    guard case .initial(let witness) = model.state,
        let authority = model.machine.authorize(using: witness)
    else {
        Issue.record("Expected Initial with an available state authority")
        return
    }

    let result: Void? = model.machine.withState(consume authority) { state in
        model.machine.finished(from: consume state)
    }

    #expect(result != nil)
    #expect(model.state.kind == .finished)
}

@Test
func scopedStateAuthorityModeSecondAuthorityCannotExtractAlreadyConsumedConcreteState() {
    let model = ConcreteStateTestModel()

    guard case .initial(let witness) = model.state,
        let firstAuthority = model.machine.authorize(using: witness),
        let secondAuthority = model.machine.authorize(using: witness)
    else {
        Issue.record("Expected Initial with available state authoritys")
        return
    }

    let first: Void? = model.machine.withState(consume firstAuthority) { state in
        model.machine.finished(from: consume state)
    }

    let second: Void? = model.machine.withState(consume secondAuthority) { _ in
        Issue.record("The concrete state must only be extractable once")
    }

    #expect(first != nil)
    #expect(second == nil)
    #expect(model.state.kind == .finished)
}

@Test
func scopedStateAuthorityModeRejectsForeignAuthorityBeforeExtractingConcreteState() {
    let first = ConcreteStateTestModel()
    let second = ConcreteStateTestModel()

    guard case .initial(let firstWitness) = first.state,
        let foreignAuthority = first.machine.authorize(using: firstWitness),
        let validAuthority = first.machine.authorize(using: firstWitness)
    else {
        Issue.record("Expected Initial authoritys")
        return
    }

    let rejected: Void? = second.machine.withState(consume foreignAuthority) { state in
        Issue.record("A authority from another model must not enter the closure")
        first.machine.finished(from: consume state)
    }
    #expect(rejected == nil)

    let accepted: Void? = first.machine.withState(consume validAuthority) { state in
        first.machine.finished(from: consume state)
    }
    #expect(accepted != nil)
    #expect(first.state.kind == .finished)
    #expect(second.state.kind == .initial)
}
