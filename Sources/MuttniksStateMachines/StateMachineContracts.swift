import CSQLite
import Foundation
import SemanticCore

@attached(member, names: named(behaviorContracts))
public macro StateMachineContracts() =
    #externalMacro(module: "MuttniksStateMachineMacros", type: "StateMachineContractsMacro")

@attached(peer)
public macro Behavior(from: Any, to: Any? = nil) =
    #externalMacro(module: "MuttniksStateMachineMacros", type: "BehaviorMarkerMacro")

public protocol NetworkAccess: Sendable {
    func requestVerification(for phone: PhoneNumber) async throws(AuthenticationError) -> Verification
    func exchange(code: Code, verification: Verification) async throws(AuthenticationError) -> Account
}

public struct PhoneNumber: Hashable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct Code: Hashable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct Verification: Hashable, Sendable {
    public let token: String
    public init(token: String) { self.token = token }
}

public struct Account: Hashable, Sendable {
    public let id: String
    public init(id: String) { self.id = id }
}

public enum AuthenticationError: Error, Sendable { case rejected }

@StateMachineContracts
public enum Authentication: Sendable, Equatable {
    case signedOut
    case awaitingCode(Verification)
    case signedIn(Account)

    @Behavior(from: Authentication.signedOut, to: Authentication.awaitingCode)
    public static func verify(
        _ phone: PhoneNumber,
        from state: Authentication,
        using network: some NetworkAccess
    ) async throws(AuthenticationError) -> Authentication {
        guard case .signedOut = state else { throw .rejected }
        let verification = try await network.requestVerification(for: phone)
        return .awaitingCode(verification)
    }

    @Behavior(from: Authentication.awaitingCode, to: Authentication.signedOut)
    public static func cancelVerification(
        from state: Authentication
    ) throws(AuthenticationError) -> Authentication {
        guard case .awaitingCode = state else { throw .rejected }
        return .signedOut
    }

    @Behavior(from: Authentication.awaitingCode, to: Authentication.signedIn)
    public static func signIn(
        _ code: Code,
        from state: Authentication,
        using network: some NetworkAccess
    ) async throws(AuthenticationError) -> Authentication {
        guard case .awaitingCode(let verification) = state else { throw .rejected }
        let account = try await network.exchange(code: code, verification: verification)
        return .signedIn(account)
    }
}

public struct BehaviorContract: Sendable, Equatable {
    public let operation: String
    public let sourceCase: String
    public let destinationCase: String?
    public let isAsync: Bool
    public let canThrow: Bool

    public init(operation: String, sourceCase: String, destinationCase: String?, isAsync: Bool, canThrow: Bool) {
        self.operation = operation
        self.sourceCase = sourceCase
        self.destinationCase = destinationCase
        self.isAsync = isAsync
        self.canThrow = canThrow
    }
}
