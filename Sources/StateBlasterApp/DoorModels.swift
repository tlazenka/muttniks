//
//  DoorModels.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum AppState {
    case initializing
    case creatingUser
    case createdUser(userId: UserId, phoneNumber: PhoneNumber)
    case onboarding(OnboardingState)
}

public enum OnboardingState {
    case initializing
    case error(Error)
    case verifying(phoneNumber: PhoneNumber)
    case verified(phoneNumber: PhoneNumber, verificationId: String)
    case verificationError(error: DataManagerError, phoneNumber: PhoneNumber)
    case signingIn
    case signedIn(phoneNumber: PhoneNumber, authUserId: String)
    case signInError(
        error: DataManagerError,
        phoneNumber: PhoneNumber,
        verificationId: String,
        verificationCode: VerificationCode
    )
    case signingOut
    case signedOut
}

enum OnboardingError: LocalizedError {
    case signInError(DataManagerError)
    case createUserError(DataManagerError)
}

public struct ApiGetUserResponse: Codable {
    public let id: UUID
    public let phoneNumber: String
    public let hashedPhoneNumber: String
    public let doorId: UUID?
    public let customDoorId: UUID?
    public let imageFilterNextAvailableDate: Date?

    public init(
        id: UUID,
        phoneNumber: String,
        hashedPhoneNumber: String,
        doorId: UUID?,
        customDoorId: UUID?,
        imageFilterNextAvailableDate: Date?
    ) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.hashedPhoneNumber = hashedPhoneNumber
        self.doorId = doorId
        self.customDoorId = customDoorId
        self.imageFilterNextAvailableDate = imageFilterNextAvailableDate
    }
}

public struct ApiKnockResponse: Codable {
    public let id: UUID
    public let sourceUserId: UUID
    public let destinationUserId: UUID?
    public let createdAt: Date
}

public typealias ApiGetKnockResponse = ApiKnockResponse

public typealias RemoteUser = ApiGetUserResponse

public struct ApiGetCustomDoorResponse: Codable, Hashable {
    public let id: UUID
    public let sourceDoorId: UUID
    public let prompt: String

    public init(
        id: UUID,
        sourceDoorId: UUID,
        prompt: String
    ) {
        self.id = id
        self.sourceDoorId = sourceDoorId
        self.prompt = prompt
    }
}

public struct ApiCreateCustomDoorRequest: Codable, Hashable {
    public let sourceDoorId: UUID
    public let prompt: String

    public init(sourceDoorId: UUID, prompt: String) {
        self.sourceDoorId = sourceDoorId
        self.prompt = prompt
    }
}

public struct ApiEmptyResponse: Decodable {}

public typealias RemoteCustomDoor = ApiGetCustomDoorResponse

public struct ApiPostUserRequest: Codable {
    public let timeOffsetMinutes: Int?
    public let fcmToken: String?
}

public struct ApiPostUserResponse: Codable {
    public let id: UUID
}

public struct ApiPostContactAvailabilityRequest: Codable {
    public let connections: [String]
}

public struct ApiPostContactAvailabilityResponse: Codable {
    public let hashedPhoneNumber: String
    public let imageName: String
}

public struct HashedPhoneNumberAndImageName {
    public let hashedPhoneNumber: HashedPhoneNumber
    public let imageName: String

    public init(hashedPhoneNumber: HashedPhoneNumber, imageName: String) {
        self.hashedPhoneNumber = hashedPhoneNumber
        self.imageName = imageName
    }
}

public struct HashedPhoneNumber: Hashable {
    let value: String
}

public extension HashedPhoneNumber {
    init?(phoneNumber: PhoneNumber) {
        guard let hashedPhoneNumber = phoneNumber.hashed else { return nil }
        value = hashedPhoneNumber
    }
}

public struct PhoneNumber: Equatable, Hashable {
    public let value: String

    public init(value: String) {
        self.value = value
    }
}

public extension PhoneNumber {
    var hashed: String? { value.sha256 }
}

extension PhoneNumber: CustomStringConvertible {
    public var description: String { value }
}

extension PhoneNumber: RawRepresentable {
    public var rawValue: String { value }

    public init?(rawValue: String) {
        value = rawValue
    }
}

public struct VerificationCode: Equatable, Hashable {
    public let value: String

    public init(value: String) {
        self.value = value
    }
}

public struct UserId: Equatable {
    public let value: UUID

    public init(value: UUID) {
        self.value = value
    }
}

extension UserId: RawRepresentable {
    public var rawValue: String { value.uuidString }

    public init?(rawValue: String) {
        guard let value = UUID(uuidString: rawValue) else {
            assertionFailure("Trying to set invalid UUID: \(rawValue)")
            return nil
        }
        self = UserId(value: value)
    }
}

public enum DataManagerError: Error {
    case errorEncoding(Error)
    case errorDecodingResponse(Error)
    case invalidResponse(URLResponse?, Data?)
    case invalidUrl
    case userNotFound
    case invalidPhoneNumberData
    case invalidStatusCode(Int)
    case urlSessionError(Error)
    case coreDataError(Error)
    case contactStore(Error)
    case contactAccessNotGranted

    case authError(Error)
    case verificationError(Error? = nil)
    case signInError(Error? = nil)
    case signOutError(Error)
    case noCurrentUser
    case getIdTokenError(Error? = nil)
    case missingPushKeys
}

public enum KnockType {
    case sent(Direction, Date)
    case received(Direction, Date)
    case acknowledged(Direction, Date)

    public struct Direction {
        public let sourceUserId: UUID
        public let destinationUserId: UUID
    }

    public var direction: Direction {
        switch self {
        case let .sent(direction, _),
            let .acknowledged(direction, _),
            let .received(direction, _):
            direction
        }
    }

    public var date: Date {
        switch self {
        case let .sent(_, date),
            let .acknowledged(_, date),
            let .received(_, date):
            date
        }
    }
}

public extension KnockType {
    init(notificationType: NotificationType, direction: Direction, date: Date) {
        switch notificationType {
        case .knock:
            self = .received(direction, date)
        case .ack:
            self = .acknowledged(direction, date)
        }
    }

    enum NotificationType: String {
        case ack = "ack"
        case knock = "knock"
    }
}

public extension String {
    var sha256: String? {
        guard let data = data(using: .utf8) else {
            return nil
        }
        return data.sha256.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension RemoteUser: Hashable {

}

#if canImport(CoreData)
import CommonCrypto

extension Data {
    var sha256: Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}
#else
extension Data {
    var sha256: Data {
        fatalError("Need to implement without CommonCrypto")
    }
}
#endif
