import Observation
import OnboardingShared
import StateBlaster
import SwiftUI

@MainActor
@Observable
@StateMachineModel(OnboardingState.self)
public final class OnboardingViewModel: OnboardingStateMachine.PresentationModel {
    public typealias Machine = OnboardingStateMachine

    public typealias NavigationEntry = Machine.NavigationEntry

    private enum HistorySnapshot {
        case initializing
        case pendingVerification(PhoneNumber)
        case pendingSignIn(VerificationCode)
        case error(any Error)
        case help
        case signedIn

        var screen: OnboardingStateMachine.Screen {
            switch self {
            case .initializing: .initializing
            case .pendingVerification: .pendingVerification
            case .pendingSignIn: .pendingSignIn
            case .error: .error
            case .help: .help
            case .signedIn: .signedIn
            }
        }
    }

    private var history: [HistorySnapshot] = [.initializing]
    private var isRestoringHistory = false

    public private(set) var state: Machine.State = Machine.initialState() {
        didSet {
            guard !isRestoringHistory else { return }
            let snapshot = Self.snapshot(of: state)
            history.append(snapshot)
            if snapshot.screen != .initializing {
                navigationPath.append(.init(screen: snapshot.screen))
            }
        }
    }
    public private(set) var navigationPath: [NavigationEntry] = []
    public var phoneNumber = ""
    public var verificationCode = ""
    public private(set) var codeEntryReady = false

    private let service: any OnboardingServiceProtocol

    public init(service: any OnboardingServiceProtocol) { self.service = service }
    public var screen: OnboardingStateMachine.Screen { state.kind.screen }
    public var presentationErrorMessage: String? {
        guard case .error(_, let error) = state else { return nil }
        return error.localizedDescription
    }

    public func setNavigationPath(_ proposed: [NavigationEntry]) {
        guard proposed.count == navigationPath.count - 1,
            history.count >= 2
        else { return }
        let previous = history[history.count - 2]
        let expected = proposed.last?.screen ?? .initializing
        guard previous.screen == expected, restorePrevious(previous) else { return }
        history.removeLast()
        navigationPath = proposed
    }

    @discardableResult
    private func restorePrevious(_ previous: HistorySnapshot) -> Bool {
        isRestoringHistory = true
        defer { isRestoringHistory = false }

        switch (state, previous) {
        case (.pendingSignIn(let witness, _), .pendingVerification(let phone)):
            guard let authority = machine.authorizeBack(using: witness) else { return false }
            machine.state = .back(consume authority, phoneNumber: phone)
            codeEntryReady = true
            phoneNumber = phone.rawValue
            return screen == .pendingVerification

        case (.help(let witness), .error(let error)):
            guard let authority = machine.authorizeBack(using: witness) else { return false }
            machine.state = .back(consume authority, error: error)
            return screen == .error

        default:
            return false
        }
    }

    private static func snapshot(of state: Machine.State) -> HistorySnapshot {
        switch state {
        case .initializing: .initializing
        case .pendingVerification(_, let phoneNumber): .pendingVerification(phoneNumber)
        case .pendingSignIn(_, let code): .pendingSignIn(code)
        case .error(_, let error): .error(error)
        case .help: .help
        case .signedIn: .signedIn
        }
    }

    public func requestCode() async {
        let phone = PhoneNumber(phoneNumber)
        guard case .initializing(let witness) = state,
            let authority = machine.authorizePendingVerificationFromInitializing(using: witness)
        else { return }
        machine.state = .pendingVerification(consume authority, phoneNumber: phone)
        codeEntryReady = false
        do { try await service.verify(phone); codeEntryReady = true } catch {
            guard case .pendingVerification(let witness, _) = state,
                let authority = machine.authorizeErrorFromPendingVerification(using: witness)
            else { return }
            machine.state = .error(consume authority, error: error)
        }
    }

    public func submitCode() async {
        let code = VerificationCode(verificationCode)
        guard case .pendingVerification(let witness, _) = state,
            let authority = machine.authorizePendingSignInFromPendingVerification(using: witness)
        else { return }
        machine.state = .pendingSignIn(consume authority, code: code)
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

    public func showHelp() {
        guard case .error(let witness, _) = state,
            let authority = machine.authorizeHelp(using: witness)
        else { return }
        machine.state = .help(consume authority)
    }

    public func requestAnotherCode() async {
        let phone = PhoneNumber(phoneNumber)
        guard case .help(let witness) = state,
            let authority = machine.authorizePendingVerificationFromHelp(using: witness)
        else { return }
        machine.state = .pendingVerification(consume authority, phoneNumber: phone)
        codeEntryReady = false
        do { try await service.verify(phone); codeEntryReady = true } catch {
            guard case .pendingVerification(let witness, _) = state,
                let authority = machine.authorizeErrorFromPendingVerification(using: witness)
            else { return }
            machine.state = .error(consume authority, error: error)
        }
    }

    public func retryCode() {
        let code = VerificationCode(verificationCode)
        guard case .help(let witness) = state,
            let authority = machine.authorizePendingSignInFromHelp(using: witness)
        else { return }
        machine.state = .pendingSignIn(consume authority, code: code)
    }
}

public typealias OnboardingFlowView = OnboardingStateMachine.PresentationView<OnboardingViewModel>
