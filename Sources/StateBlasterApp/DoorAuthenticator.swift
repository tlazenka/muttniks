//
//  DoorAuthenticator.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import Foundation

public protocol SignInResultProtocol: Sendable {
    var authUserId: String { get }
}

public protocol DoorAuthenticator {
    associatedtype GetCredentialResult
    associatedtype SignInResult: SignInResultProtocol
    associatedtype APNSTokenType

    func verifyPhoneNumber(
        _ phoneNumber: String,
        completionHandler: @escaping (Result<String, DataManagerError>) -> Void
    )

    func getCredential(verificationId: String, verificationCode: VerificationCode) -> GetCredentialResult

    func signIn(
        with credential: GetCredentialResult,
        completionHandler: @escaping (Result<SignInResult, DataManagerError>) -> Void
    )

    func signOut(completionHandler: @escaping (Result<Void, DataManagerError>) -> Void)

    func getIdToken(completionHandler: @escaping (Result<String, DataManagerError>) -> Void)

    func setAPNSToken(_ token: Data, type: APNSTokenType)

    func canHandleNotification(_ userInfo: [AnyHashable: Any]) -> Bool

    func canHandle(_ url: URL) -> Bool

    var currentUserId: String? { get }

    var fcmToken: String? { get }
}

public extension DoorAuthenticator {
    func getIdToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.getIdToken {
                continuation.resume(with: $0)
            }
        }
    }

    func signIn(with credential: GetCredentialResult) async throws -> SignInResult {
        try await withCheckedThrowingContinuation { continuation in
            self.signIn(with: credential) {
                continuation.resume(with: $0)
            }
        }
    }

    func verifyPhoneNumber(_ phoneNumber: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.verifyPhoneNumber(phoneNumber) {
                continuation.resume(with: $0)
            }
        }
    }

    func signOut() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.signOut {
                continuation.resume(with: $0)
            }
        }
    }
}
