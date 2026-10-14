import OnboardingFeature
import SwiftUI

@main
struct OnboardingDemoApp: App {
    var body: some Scene {
        WindowGroup {
            OnboardingFeature.OnboardingFlowView(
                model: OnboardingFeature.OnboardingViewModel(service: DemoOnboardingService())
            )
        }
    }
}

@MainActor
struct DemoOnboardingService: OnboardingServiceProtocol {
    func verify(_ phoneNumber: PhoneNumber) async throws {
        try await Task.sleep(for: .milliseconds(650))
    }
    func signIn(_ code: VerificationCode) async throws {
        try await Task.sleep(for: .milliseconds(850))
    }
}
