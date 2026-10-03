import Foundation
import Observation
import StateBlaster
import SwiftUI

public struct PhoneNumber: Equatable, Sendable {
    public let rawValue: String; public init(_ rawValue: String) { self.rawValue = rawValue }
}
public struct VerificationCode: Equatable, Sendable {
    public let rawValue: String; public init(_ rawValue: String) { self.rawValue = rawValue }
}

@MainActor public protocol OnboardingServiceProtocol {
    func verify(_ phoneNumber: PhoneNumber) async throws
    func signIn(_ code: VerificationCode) async throws
}

@StateMachine(mode: .transitionAuthority)
@SwiftUIPresentation
public enum OnboardingState {
    @MachineState(initial: true, transitions: ["pendingVerification"])
    @Screen(
        title: "Welcome In",
        message: "Please enter your phone number and tap Send Code.",
        systemImage: "candybarphone",
        kind: .form,
        fields: [.text("phoneNumber", label: "Phone Number", contentType: "telephoneNumber")],
        actions: [.async("requestCode", title: "Send Code", enabledWhen: .nonEmpty("phoneNumber"))]
    )
    case initializing

    @MachineState(transitions: ["pendingSignIn", "error"])
    @Screen(
        title: "Verification Code",
        message:
            "Please enter the SMS verification code we sent and tap Sign In. You may need to wait up to 2 minutes for the code",
        systemImage: "fire.extinguisher",
        kind: .form,
        fields: [.text("verificationCode", label: "Verification Code", contentType: "oneTimeCode")],
        actions: [.async("submitCode", title: "Sign In", enabledWhen: .nonEmpty("verificationCode"))],
        visibleWhen: .flag("codeEntryReady"),
        fallback: .progress
    )
    case pendingVerification(phoneNumber: PhoneNumber)

    @MachineState(transitions: ["signedIn", "error"], back: "pendingVerification")
    @Screen(
        title: "Loading...",
        message: "",
        systemImage: "carbon.monoxide.cloud.fill",
        kind: .progress
    )
    case pendingSignIn(code: VerificationCode)

    @MachineState(transitions: ["help"])
    @Screen(
        title: "Sorry, there was an error.",
        message: "",
        systemImage: "figure.seated.side.right.air.distribution.upper.angled.and.dottedline.and.lower.angled",
        kind: .error,
        actions: [.sync("showHelp", title: "Get help")]
    )
    case error(error: Error)

    @MachineState(transitions: ["pendingVerification", "pendingSignIn"], back: "error")
    @Screen(
        title: "",
        message: "Try 123456 as your Verification Code (it always works).",
        systemImage: "cart.badge.questionmark",
        kind: .help,
        actions: [
            .async("requestAnotherCode", title: "Request a new code"),
            .sync("retryCode", title: "Retry code", enabledWhen: .nonEmpty("verificationCode")),
        ]
    )
    case help

    @MachineState
    @Screen(
        title: "Congratulations!",
        message: "Consider yourself onboarded.",
        systemImage: "service.dog.fill",
        kind: .success
    )
    case signedIn
}

public struct PreviewRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15; var z = state; z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9;
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB; return z ^ (z >> 31)
    }
}
public protocol SampleValue { static func sample(using generator: inout PreviewRandomNumberGenerator) -> Self }
extension PhoneNumber: SampleValue {
    public static func sample(using generator: inout PreviewRandomNumberGenerator) -> Self {
        .init("+1 555 010 \(Int.random(in: 1000...9999, using: &generator))")
    }
}
extension VerificationCode: SampleValue {
    public static func sample(using generator: inout PreviewRandomNumberGenerator) -> Self {
        .init(String(Int.random(in: 100_000...999_999, using: &generator)))
    }
}
public struct OnboardingSampleError: LocalizedError, Sendable {
    public let errorDescription: String?; public init(_ message: String) { errorDescription = message }
}
public enum OnboardingSamples {
    public static func phone(seed: UInt64 = 32) -> PhoneNumber {
        var g = PreviewRandomNumberGenerator(seed: seed); return .sample(using: &g)
    }
    public static func code(seed: UInt64 = 32) -> VerificationCode {
        var g = PreviewRandomNumberGenerator(seed: seed); return .sample(using: &g)
    }
    public static func error(seed: UInt64 = 32) -> OnboardingSampleError {
        var g = PreviewRandomNumberGenerator(seed: seed); let n = Int.random(in: 100...999, using: &g);
        return .init("Verification failed (sample \(n)).")
    }
}
