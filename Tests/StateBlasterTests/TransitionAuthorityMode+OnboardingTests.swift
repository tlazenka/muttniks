//
//  TransitionAuthorityMode+OnboardingTests.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/16/26.
//

import StateBlaster
import Testing

private struct PhoneNumber: Equatable, Sendable {
    let rawValue: String
    init(_ rawValue: String) { self.rawValue = rawValue }
}

private struct VerificationCode: Equatable, Sendable {
    let rawValue: String
    init(_ rawValue: String) { self.rawValue = rawValue }
}

@MainActor
private protocol OnboardingServiceProtocol {
    func verify(_ phoneNumber: PhoneNumber) async throws
    func signIn(_ code: VerificationCode) async throws
}

@StateMachine(mode: .transitionAuthority)
private enum RichOnboardingState {
    @MachineState(initial: true, transitions: ["pendingVerification"])
    case initializing

    @MachineState(transitions: ["pendingSignIn", "error"])
    case pendingVerification(phoneNumber: PhoneNumber)

    @MachineState(transitions: ["signedIn", "error"])
    case pendingSignIn(code: VerificationCode)

    @MachineState(transitions: ["initializing"])
    case error(error: Error)

    @MachineState
    case signedIn
}

@MainActor
@StateMachineModel(RichOnboardingState.self)
private final class RichOnboardingModel {
    typealias Machine = RichOnboardingStateMachine
    private(set) var state: Machine.State = Machine.initialState()
    private(set) var isCodeEntryVisible = false
    private let service: any OnboardingServiceProtocol

    init(service: any OnboardingServiceProtocol) { self.service = service }

    func requestCode(_ phone: PhoneNumber) async {
        guard case .initializing(let witness) = state,
            let authority = machine.authorizePendingVerification(using: witness)
        else { return }
        machine.state = .pendingVerification(consume authority, phoneNumber: phone)
        do {
            try await service.verify(phone)
            isCodeEntryVisible = true
        } catch {
            guard case .pendingVerification(let witness, _) = state,
                let authority = machine.authorizeErrorFromPendingVerification(using: witness)
            else { return }
            machine.state = .error(consume authority, error: error)
        }
    }

    func submit(_ code: VerificationCode) async {
        guard case .pendingVerification(let witness, _) = state,
            let authority = machine.authorizePendingSignIn(using: witness)
        else { return }
        machine.state = .pendingSignIn(consume authority, code: code)
        isCodeEntryVisible = false
        do {
            try await service.signIn(code)
            guard case .pendingSignIn(let witness, _) = state,
                let authority = machine.authorizeSignedIn(using: witness)
            else { return }
            machine.state = .signedIn(consume authority)
        } catch {
            guard case .pendingSignIn(let witness, _) = state,
                let authority = machine.authorizeErrorFromPendingSignIn(using: witness)
            else { return }
            machine.state = .error(consume authority, error: error)
        }
    }

    func startOver() {
        guard case .error(let witness, _) = state,
            let authority = machine.authorizeInitializing(using: witness)
        else { return }
        machine.state = .initializing(consume authority)
    }

}

private enum TestFailure: Error { case verify, signIn }

@MainActor
private final class OnboardingServiceMock: OnboardingServiceProtocol {
    var verifyError: Error?
    var signInError: Error?
    private(set) var verifiedPhones: [PhoneNumber] = []
    private(set) var submittedCodes: [VerificationCode] = []

    func verify(_ phoneNumber: PhoneNumber) async throws {
        verifiedPhones.append(phoneNumber)
        if let verifyError { throw verifyError }
    }

    func signIn(_ code: VerificationCode) async throws {
        submittedCodes.append(code)
        if let signInError { throw signInError }
    }
}

@Test @MainActor
func onboardingRequestsCodeThenWaitsForUserCode() async {
    let service = OnboardingServiceMock()
    let model = RichOnboardingModel(service: service)
    let phone = PhoneNumber("+1 777-FILM")

    await model.requestCode(phone)

    #expect(service.verifiedPhones == [phone])
    #expect(model.state.kind == .pendingVerification)
    #expect(model.isCodeEntryVisible)
    guard case .pendingVerification(_, let storedPhone) = model.state else {
        Issue.record("Expected pendingVerification")
        return
    }
    #expect(storedPhone == phone)
}

@Test @MainActor
func onboardingSubmitsTypedCodeAndSignsIn() async {
    let service = OnboardingServiceMock()
    let model = RichOnboardingModel(service: service)
    let code = VerificationCode("123456")

    await model.requestCode(PhoneNumber("+1 777-FILM"))
    await model.submit(code)

    #expect(service.submittedCodes == [code])
    #expect(model.state.kind == .signedIn)
}

@Test @MainActor
func verificationFailureTransitionsToErrorThenStartOver() async {
    let service = OnboardingServiceMock()
    service.verifyError = TestFailure.verify
    let model = RichOnboardingModel(service: service)

    await model.requestCode(PhoneNumber("+1 777-FILM"))
    #expect(model.state.kind == .error)

    model.startOver()
    #expect(model.state.kind == .initializing)
}

@Test @MainActor
func signInFailureTransitionsToErrorThenStartOver() async {
    let service = OnboardingServiceMock()
    service.signInError = TestFailure.signIn
    let model = RichOnboardingModel(service: service)

    await model.requestCode(PhoneNumber("+1 777-FILM"))
    await model.submit(VerificationCode("123456"))
    #expect(model.state.kind == .error)

    model.startOver()
    #expect(model.state.kind == .initializing)
}
