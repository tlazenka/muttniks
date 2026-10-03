import Foundation

@testable import StateBlasterApp

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct SignInResultMock: SignInResultProtocol {
    var authUserId: String = "mock"
}

class AuthenticatorMock: DoorAuthenticator {
    func canHandleNotification(_: [AnyHashable: Any]) -> Bool {
        true
    }

    func canHandle(_: URL) -> Bool {
        true
    }

    typealias GetCredentialResult = String
    typealias SignInResult = SignInResultMock

    func verifyPhoneNumber(_: String, completionHandler: @escaping (Result<String, DataManagerError>) -> Void) {
        completionHandler(.success("mockVerificationId"))
    }

    func getCredential(verificationId _: String, verificationCode _: VerificationCode) -> GetCredentialResult {
        "mockCredential"
    }

    func signIn(
        with _: GetCredentialResult,
        completionHandler: @escaping (Result<SignInResult, DataManagerError>) -> Void
    ) {
        completionHandler(.success(SignInResultMock(authUserId: "mockAuthUserId")))
    }

    func signOut(completionHandler: @escaping (Result<Void, DataManagerError>) -> Void) {
        completionHandler(.success(()))
    }

    func getIdToken(completionHandler: @escaping (Result<String, DataManagerError>) -> Void) {
        completionHandler(.success("mockIdToken"))
    }

    func setAPNSToken(_: Data, type _: String) {}

    var currentUserId: String? { "mockCurrentUserId" }

    var fcmToken: String? { "mockFcmToken" }
}

extension DoorRemoteDataManager {
    static func makeMock(urlSessionConfiguration: URLSessionConfiguration) -> DoorRemoteDataManager {
        DoorRemoteDataManager(
            urlSession: .init(configuration: urlSessionConfiguration),
            baseUrl: URL(string: "mock")!,
            apiKey: "mock",
        )
    }
}
