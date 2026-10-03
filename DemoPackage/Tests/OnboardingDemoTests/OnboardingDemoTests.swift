import OnboardingShared
import OnboardingSwiftUI
import Testing

@Test func seededSamplesAreStable() {
    #expect(OnboardingSamples.phone(seed: 32) == OnboardingSamples.phone(seed: 32))
    #expect(OnboardingSamples.code(seed: 32) == OnboardingSamples.code(seed: 32))
}
@Test func everyMachinePresentationStateHasADescriptor() {
    #expect(Set(OnboardingStateMachine.screens.map(\.state)) == Set(OnboardingStateMachine.Screen.allCases))
}
@Test func differentSeedsProduceUsefulVariation() {
    #expect(OnboardingSamples.code(seed: 1) != OnboardingSamples.code(seed: 2))
}

@MainActor
private final class NavigationDemoService: OnboardingServiceProtocol {
    var verified: [PhoneNumber] = []
    var signedIn: [VerificationCode] = []
    func verify(_ phoneNumber: PhoneNumber) async throws { verified.append(phoneNumber) }
    func signIn(_ code: VerificationCode) async throws { signedIn.append(code) }
}

@Test @MainActor
func interactiveSwiftUIModelFollowsInputsThroughMachineStates() async {
    let service = NavigationDemoService()
    let model = OnboardingViewModel(service: service)
    model.phoneNumber = "+1 777-FILM"

    await model.requestCode()
    #expect(model.screen == .pendingVerification)
    #expect(model.navigationPath.map(\.screen) == [.pendingVerification])
    #expect(model.codeEntryReady)
    #expect(service.verified == [PhoneNumber("+1 777-FILM")])

    model.verificationCode = "123456"
    await model.submitCode()
    #expect(model.screen == .signedIn)
    #expect(model.navigationPath.map(\.screen) == [.pendingVerification, .pendingSignIn, .signedIn])
    #expect(service.signedIn == [VerificationCode("123456")])
}

@MainActor
private final class SuspendingNavigationService: OnboardingServiceProtocol {
    func verify(_ phoneNumber: PhoneNumber) async throws {}
    func signIn(_ code: VerificationCode) async throws {
        try await Task.sleep(for: .seconds(60))
    }
}

@Test @MainActor
func boundPathPopRestoresPayloadForAnExplicitBackEdge() async {
    let model = OnboardingViewModel(service: SuspendingNavigationService())
    model.phoneNumber = "+1 777-FILM"
    await model.requestCode()
    model.verificationCode = "123456"

    let signIn = Task { await model.submitCode() }
    while model.screen != .pendingSignIn { await Task.yield() }

    #expect(model.navigationPath.map(\.screen) == [.pendingVerification, .pendingSignIn])
    model.setNavigationPath(Array(model.navigationPath.dropLast()))

    #expect(model.screen == .pendingVerification)
    #expect(model.phoneNumber == "+1 777-FILM")
    #expect(model.navigationPath.map(\.screen) == [.pendingVerification])

    signIn.cancel()
    await signIn.value
}

@Test @MainActor
func boundPathRejectsBackWhenTheADTDeclaresNoBackEdge() async {
    let service = NavigationDemoService()
    let model = OnboardingViewModel(service: service)
    model.phoneNumber = "+1 777-FILM"
    await model.requestCode()
    model.verificationCode = "123456"
    await model.submitCode()

    let fullPath = model.navigationPath
    model.setNavigationPath(Array(fullPath.dropLast()))

    #expect(model.screen == .signedIn)
    #expect(model.navigationPath == fullPath)
}
