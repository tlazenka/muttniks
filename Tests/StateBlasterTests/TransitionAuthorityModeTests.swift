//
//  TransitionAuthorityModeTests.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import StateBlaster
import Testing

@StateMachine(mode: .transitionAuthority)
private enum EdgeTestState {
    @MachineState(initial: true, transitions: ["finished", "cancelled"])
    case initial

    @MachineState
    case finished

    @MachineState
    case cancelled
}

@StateMachineModel(EdgeTestState.self)
private final class EdgeTestModel {
    typealias Machine = EdgeTestStateMachine
    private(set) var state: Machine.State

    init() {
        state = Machine.initialState()
    }
}

@Test
func transitionAuthorityModeUsesAnExactMoveOnlyEdgeCapability() {
    let model = EdgeTestModel()

    guard case .initial(let witness) = model.state,
        let authority = model.machine.authorizeFinished(using: witness)
    else {
        Issue.record("Expected Initial with a finished edge")
        return
    }

    model.machine.state = .finished(consume authority)
    #expect(model.state.kind == .finished)
}

@Test
func transitionAuthorityModeCanSelectAnotherLegalOutgoingEdge() {
    let model = EdgeTestModel()

    guard case .initial(let witness) = model.state,
        let authority = model.machine.authorizeCancelled(using: witness)
    else {
        Issue.record("Expected Initial with a cancelled edge")
        return
    }

    model.machine.state = .cancelled(consume authority)
    #expect(model.state.kind == .cancelled)
}

@Test
func rejectedEdgeCapabilityDoesNotConsumeTheOriginalModelState() {
    let first = EdgeTestModel()
    let second = EdgeTestModel()

    guard case .initial(let firstWitness) = first.state,
        let foreignAuthority = first.machine.authorizeFinished(using: firstWitness)
    else {
        Issue.record("Expected Initial")
        return
    }

    second.machine.state = .finished(consume foreignAuthority)
    #expect(second.state.kind == .initial)

    guard let authority = first.machine.authorizeCancelled(using: firstWitness) else {
        Issue.record("Rejected edge unexpectedly consumed the source state")
        return
    }

    first.machine.state = .cancelled(consume authority)
    #expect(first.state.kind == .cancelled)
}
