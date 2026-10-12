//
//  OnboardingModel.swift
//  Onboarding
//
//  Created by Francis Lazenka on 9/15/26.
//

import Combine
import Foundation
import Observation
import StateBlaster

struct PhoneNumber: Hashable { let rawValue: String }

@StateMachine(mode: .transitionAuthority)
enum OnboardingState {
    @MachineState(initial: true, transitions: ["codeEntry", "phoneError"])
    case phoneEntry

    @MachineState(transitions: ["finished", "codeError"])
    case codeEntry(phoneNumber: PhoneNumber)

    @MachineState(transitions: ["phoneEntry"])
    case phoneError(error: Error)

    @MachineState(transitions: ["codeEntry"])
    case codeError(phoneNumber: PhoneNumber, error: Error)

    @MachineState
    case finished
}

@MainActor
@Observable
@StateMachineModel(OnboardingState.self)
final class OnboardingModel {
    public typealias Machine = OnboardingStateMachine

    public internal(set) var state: Machine.State = Machine.initialState()
}
