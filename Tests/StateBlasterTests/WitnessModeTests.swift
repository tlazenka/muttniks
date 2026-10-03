//
//  WitnessModeTests.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import StateBlaster
import Testing

private struct PhoneNumber: Equatable, Sendable {
    let rawValue: String
}

private struct VerificationCode: Equatable, Sendable {
    let rawValue: String
}

private enum OnboardingServiceError: Error, Equatable {
    case verificationFailed
    case signInFailed
}

@MainActor private protocol OnboardingServiceProtocol {
    func verify(_ phoneNumber: PhoneNumber) async throws
    func signIn(_ code: VerificationCode) async throws
}

private final class OnboardingServiceMock: OnboardingServiceProtocol {
    private(set) var verifiedPhoneNumbers: [PhoneNumber] = []
    private(set) var signedInCodes: [VerificationCode] = []

    var verifyResult: Result<Void, OnboardingServiceError>
    var signInResult: Result<Void, OnboardingServiceError>

    init(
        verifyResult: Result<Void, OnboardingServiceError> = .success(()),
        signInResult: Result<Void, OnboardingServiceError> = .success(())
    ) {
        self.verifyResult = verifyResult
        self.signInResult = signInResult
    }

    func verify(_ phoneNumber: PhoneNumber) async throws {
        verifiedPhoneNumbers.append(phoneNumber)
        return try verifyResult.get()
    }

    func signIn(_ code: VerificationCode) async throws {
        signedInCodes.append(code)
        try signInResult.get()
    }
}

@StateMachine(mode: .witness)
private enum CopyableOnboardingState {
    @MachineState(initial: true, transitions: ["pendingVerification"])
    case initializing

    @MachineState(transitions: ["pendingSignIn"])
    case pendingVerification(phoneNumber: PhoneNumber)

    @MachineState(transitions: ["signedIn"])
    case pendingSignIn(code: VerificationCode)

    @MachineState
    case signedIn
}

@StateMachineModel(CopyableOnboardingState.self)
private final class CopyableOnboardingModel {
    typealias Machine = CopyableOnboardingStateMachine
    private(set) var state: Machine.State

    init() {
        state = Machine.initialState()
    }
}

@Test
@MainActor func copyableModeHappyPath() async throws {
    let service = OnboardingServiceMock()
    let model = CopyableOnboardingModel()
    let phoneNumber = PhoneNumber(rawValue: "+1 777-FILM")

    guard case .initializing(let initializingWitness) = model.state else {
        Issue.record("Expected Initializing")
        return
    }

    model.machine.state = .pendingVerification(
        initializingWitness,
        phoneNumber: phoneNumber
    )

    guard case .pendingVerification(let verificationWitness, let currentPhoneNumber) = model.state else {
        Issue.record("Expected PendingVerification")
        return
    }
    #expect(currentPhoneNumber == phoneNumber)

    try await service.verify(currentPhoneNumber)
    model.machine.state = .pendingSignIn(verificationWitness, code: VerificationCode(rawValue: "123456"))

    guard case .pendingSignIn(let signInWitness, let currentCode) = model.state else {
        Issue.record("Expected PendingSignIn")
        return
    }

    try await service.signIn(currentCode)
    model.machine.state = .signedIn(signInWitness)

    #expect(model.state.kind == .signedIn)
    #expect(model.state.isTerminal)
    #expect(await service.verifiedPhoneNumbers == [phoneNumber])
    #expect(await service.signedInCodes == [VerificationCode(rawValue: "123456")])
}

@Test
func copyableModeCarriesPayloadAlongsideWitness() {
    let model = CopyableOnboardingModel()
    let phoneNumber = PhoneNumber(rawValue: "+1 777-FILM")

    guard case .initializing(let witness) = model.state else {
        Issue.record("Expected Initializing")
        return
    }

    model.machine.state = .pendingVerification(witness, phoneNumber: phoneNumber)

    guard case .pendingVerification(_, let payload) = model.state else {
        Issue.record("Expected PendingVerification")
        return
    }

    #expect(payload == phoneNumber)
    #expect(model.state.allowedTransitions == [.pendingSignIn])
}

@Test
func copyableModeRejectsAStaleWitness() {
    let model = CopyableOnboardingModel()
    let phoneNumber = PhoneNumber(rawValue: "+1 777-FILM")

    guard case .initializing(let witness) = model.state else {
        Issue.record("Expected Initializing")
        return
    }

    model.machine.state = .pendingVerification(witness, phoneNumber: phoneNumber)
    model.machine.state = .pendingVerification(
        witness,
        phoneNumber: PhoneNumber(rawValue: "+1 777-FILM")
    )

    guard case .pendingVerification(_, let currentPhoneNumber) = model.state else {
        Issue.record("Expected PendingVerification")
        return
    }
    #expect(currentPhoneNumber == phoneNumber)
}

@Test
func copyableModeRejectsAWitnessFromAnotherModel() {
    let first = CopyableOnboardingModel()
    let second = CopyableOnboardingModel()

    guard case .initializing(let firstWitness) = first.state else {
        Issue.record("Expected Initializing")
        return
    }

    second.machine.state = .pendingVerification(
        firstWitness,
        phoneNumber: PhoneNumber(rawValue: "+1 777-FILM")
    )

    #expect(second.state.kind == .initializing)
}
