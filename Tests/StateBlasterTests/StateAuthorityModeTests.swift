//
//  StateAuthorityModeTests.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import StateBlaster
import Testing

@StateMachine(mode: .stateAuthority)
private enum DirectStateTestState {
    @MachineState(initial: true, transitions: ["finished", "cancelled"])
    case initial(value: Int)

    @MachineState
    case finished(value: Int)

    @MachineState
    case cancelled(value: Int)
}

@StateMachineModel(DirectStateTestState.self)
private final class DirectStateTestModel {
    typealias Machine = DirectStateTestStateMachine
    private(set) var state: Machine.State

    init(value: Int = 32) {
        state = Machine.initialState(value: value)
    }
}

@Test
func stateAuthorityModeReturnsConcreteMoveOnlyStateWithoutClosure() {
    let model = DirectStateTestModel(value: 32)
    guard case .initial(let witness, _) = model.state,
        let authority = model.machine.authorize(using: witness),
        let state = model.machine.acquire(consume authority)
    else {
        Issue.record("Expected concrete Initial state")
        return
    }

    #expect(state.value == 32)
    model.machine.finished(from: consume state)
    #expect(model.state.kind == .finished)
}

@Test
func stateAuthorityModeCanChooseOutgoingEdgeAfterTakingState() {
    let model = DirectStateTestModel()
    guard case .initial(let witness, _) = model.state,
        let authority = model.machine.authorize(using: witness),
        let state = model.machine.acquire(consume authority)
    else {
        Issue.record("Expected concrete Initial state")
        return
    }

    model.machine.cancelled(from: consume state)
    #expect(model.state.kind == .cancelled)
}

@Test
func stateAuthorityModeRejectsStaleAuthorityBeforeExtractingItsState() {
    let first = DirectStateTestModel()
    let second = DirectStateTestModel()
    guard case .initial(let firstWitness, _) = first.state,
        case .initial(let secondWitness, _) = second.state,
        let staleForSecond = first.machine.authorize(using: firstWitness),
        let validForFirst = first.machine.authorize(using: firstWitness),
        let validForSecond = second.machine.authorize(using: secondWitness)
    else {
        Issue.record("Expected authoritys")
        return
    }

    if let unexpected = second.machine.acquire(consume staleForSecond) {
        Issue.record("A authority from another model must be rejected")
        _ = consume unexpected
    }

    guard let firstState = first.machine.acquire(consume validForFirst),
        let secondState = second.machine.acquire(consume validForSecond)
    else {
        Issue.record("Rejected authority must not consume either model's concrete state")
        return
    }

    first.machine.finished(from: consume firstState)
    second.machine.cancelled(from: consume secondState)
    #expect(first.state.kind == .finished)
    #expect(second.state.kind == .cancelled)
}

@Test
func stateAuthorityModeOnlyExtractsConcreteStateOnce() {
    let model = DirectStateTestModel()
    guard case .initial(let witness, _) = model.state,
        let firstAuthority = model.machine.authorize(using: witness),
        let secondAuthority = model.machine.authorize(using: witness)
    else {
        Issue.record("Expected authoritys")
        return
    }

    guard let state = model.machine.acquire(consume firstAuthority) else {
        Issue.record("Expected first extraction")
        return
    }
    if let unexpected = model.machine.acquire(consume secondAuthority) {
        Issue.record("The concrete state must only be extractable once")
        _ = consume unexpected
    }
    model.machine.finished(from: consume state)
}
