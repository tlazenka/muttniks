import OnboardingShared
import OnboardingSwiftUI
import SwiftUI

@MainActor
struct DemoOnboardingService: OnboardingServiceProtocol {
    func verify(_ phoneNumber: PhoneNumber) async throws {
        try await Task.sleep(for: .milliseconds(650))
    }
    func signIn(_ code: VerificationCode) async throws {
        try await Task.sleep(for: .milliseconds(850))
    }
}

public struct OnboardingFlowView: View {
    public init() {

    }

    public var body: some View {
        OnboardingSwiftUI.OnboardingFlowView(model: OnboardingViewModel(service: DemoOnboardingService()))
    }
}
