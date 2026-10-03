//
//  DoorDataManager.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

#if canImport(CoreData)
import CoreData
import Foundation

public final class DoorDataManager<Credential, SignInResult, APNSTokenType, AuthenticatorType>
where
    AuthenticatorType: DoorAuthenticator, AuthenticatorType.GetCredentialResult == Credential,
    AuthenticatorType.APNSTokenType == APNSTokenType
{
    public let userDefaults: UserDefaults
    public let notificationCenter: NotificationCenter
    public let coreDataManager: DoorCoreDataManager
    private let remoteDataManager: DoorRemoteDataManager
    public let authenticator: AuthenticatorType
    let blobCache: DataCache
    let isLegacyUser: Bool
    let isUpgradeFromBeforeOnePointThree: Bool

    @UserDefault public var appBundleShortVersion: String?
    @UserDefault public var appBundleVersion: String?
    @UserDefault var authUserId: String?
    @UserDefault public internal(set) var phoneNumber: PhoneNumber?
    @BoolUserDefault<Bool> public var shouldCheckContactsAutomatically: Bool
    @BoolUserDefault<Bool> public var didShowWhatIsNewDialog: Bool
    @UserDefault public internal(set) var userId: UserId?

    public init(
        coreDataManager: DoorCoreDataManager,
        remoteDataManager: DoorRemoteDataManager,
        authenticator: AuthenticatorType,
        userDefaults: UserDefaults,
        notificationCenter: NotificationCenter,
        blobCache: DataCache
    ) {
        self.userDefaults = userDefaults
        self.coreDataManager = coreDataManager
        self.remoteDataManager = remoteDataManager

        _appBundleVersion = .init(key: "appBundleVersion", store: userDefaults)
        _appBundleShortVersion = .init(key: "appBundleShortVersion", store: userDefaults)

        isLegacyUser = userDefaults.object(forKey: "verificationId") != nil
        let shouldCheckContactsAutomaticallyDefault = !isLegacyUser

        _authUserId = .init(key: "authUserId", store: userDefaults)

        _userId = .init(key: "userId", store: userDefaults)
        _phoneNumber = .init(key: "phoneNumber", store: userDefaults)

        isUpgradeFromBeforeOnePointThree =
            (userDefaults.object(forKey: "appBundleShortVersion") as? String)
            .flatMap {
                Double($0)
            }
            .map {
                $0 < 1.3
            } ?? false

        _shouldCheckContactsAutomatically = .init(
            key: "shouldCheckContactsAutomatically",
            defaultValue: shouldCheckContactsAutomaticallyDefault,
            store: userDefaults
        )
        _didShowWhatIsNewDialog = .init(
            key: "didShowWhatIsNewDialog",
            defaultValue: false,
            store: userDefaults
        )

        self.authenticator = authenticator
        self.notificationCenter = notificationCenter
        self.blobCache = blobCache
    }

    public var isSignedIn: Bool {
        userId != nil
    }

    public func getUser() async throws -> RemoteUser {
        let accessToken = try await authenticator.getIdToken()

        let remoteUser = try await remoteDataManager.getUser(accessToken: accessToken)
        return try await coreDataManager.insertUser(remoteUser: remoteUser)
    }

    func createUser(timeOffsetMinutes: Int) async throws -> ApiPostUserResponse {
        let accessToken = try await authenticator.getIdToken()

        return try await remoteDataManager.createUser(accessToken: accessToken, timeOffsetMinutes: timeOffsetMinutes)
    }

    func updateFcmRegistrationTokenPublisher(fcmRegistrationToken: String) async throws -> ApiPostUserResponse {
        let accessToken = try await authenticator.getIdToken()

        return try await remoteDataManager.updateFcmRegistrationToken(
            accessToken: accessToken,
            fcmRegistrationToken: fcmRegistrationToken
        )
    }

    public func updateDoorId(doorId: UUID) async throws -> RemoteUser {
        let accessToken = try await authenticator.getIdToken()

        let remoteUser = try await remoteDataManager.updateDoorId(accessToken: accessToken, doorId: doorId)

        try await coreDataManager.insertUsers(remoteUsers: [remoteUser], cnContactIdentifier: nil)

        return remoteUser
    }

    public func updateDoorId(sourceDoorId: UUID, prompt: String) async throws -> RemoteUser {
        let accessToken = try await authenticator.getIdToken()

        let remoteUser = try await remoteDataManager.updateDoorId(
            accessToken: accessToken,
            sourceDoorId: sourceDoorId,
            prompt: prompt
        )

        try await coreDataManager.insertUsers(remoteUsers: [remoteUser], cnContactIdentifier: nil)

        return remoteUser
    }

    public func getUsers(
        phoneNumbers: [PhoneNumber],
        addingCnContactIdentifier cnContactIdentifier: String?
    ) async throws -> [ApiGetUserResponse] {
        let accessToken = try await authenticator.getIdToken()

        let remoteUsers = try await remoteDataManager.getUsers(accessToken: accessToken, phoneNumbers: phoneNumbers)

        return try await coreDataManager.insertUsers(remoteUsers: remoteUsers, cnContactIdentifier: cnContactIdentifier)
    }

    public func knock(destinationUserId: UUID, imageData: Data?) async throws -> ApiKnockResponse {
        let accessToken = try await authenticator.getIdToken()
        let knock = try await remoteDataManager.knock(
            accessToken: accessToken,
            destinationUserId: destinationUserId,
            imageData: imageData
        )

        try await coreDataManager.insertKnock(
            id: knock.id,
            knockType: .sent(.init(sourceUserId: knock.sourceUserId, destinationUserId: destinationUserId), Date())
        )

        if let imageData {
            try await coreDataManager.insertBlob(id: knock.id.uuidString, data: imageData)
        }

        return knock
    }

    public func acknowledgeKnock(knockId: UUID) async throws {
        let accessToken = try await authenticator.getIdToken()

        try await remoteDataManager.acknowledgeKnock(accessToken: accessToken, knockId: knockId)
    }

    public func getAvailableDoors() async throws -> [RemoteCustomDoor] {
        let accessToken = try await authenticator.getIdToken()

        let remoteDoors = try await remoteDataManager.getAvailableDoors(accessToken: accessToken)
        return try await coreDataManager.insertDoors(remoteDoors: remoteDoors)
    }

    public func getImageData(doorId: UUID) async throws -> Data {
        if let imageData = blobCache.data(forKey: doorId.uuidString) {
            return imageData
        }

        let data = try await coreDataManager.getBlob(id: doorId.uuidString)
        if let imageData = data {
            blobCache.set(data: imageData, forKey: doorId.uuidString)
            return imageData
        }

        let accessToken = try await authenticator.getIdToken()

        let imageData = try await remoteDataManager.getImageData(accessToken: accessToken, doorId: doorId)
        blobCache.set(data: imageData, forKey: doorId.uuidString)
        return try await coreDataManager.insertBlob(id: doorId.uuidString, data: imageData)
    }

    public func getImageData(knockId: UUID) async throws -> Data {
        if let imageData = blobCache.data(forKey: knockId.uuidString) {
            return imageData
        }
        let localData = try await coreDataManager.getBlob(id: knockId.uuidString)

        if let imageData = localData {
            blobCache.set(data: imageData, forKey: knockId.uuidString)
            return imageData
        }

        let accessToken = try await authenticator.getIdToken()

        let data = try await remoteDataManager.getImageData(accessToken: accessToken, knockId: knockId)

        blobCache.set(data: data, forKey: knockId.uuidString)

        try await coreDataManager.insertBlob(id: knockId.uuidString, data: data)

        return data
    }

    public func getPhoneNumber(userId: UUID) async throws -> String? {
        try await coreDataManager.getPhoneNumber(userId: userId)
    }

    public func getKnocks() async throws {
        let accessToken = try await authenticator.getIdToken()

        let remoteKnocks = try await remoteDataManager.getKnocks(accessToken: accessToken)

        try await coreDataManager.insertKnocks(remoteKnocks)
    }

    public func deleteAccount() async throws {
        let accessToken = try await authenticator.getIdToken()

        try await remoteDataManager.deleteAccount(accessToken: accessToken)
    }
}

extension UserDefaults {
    @objc dynamic var shouldCheckContactsAutomatically: Bool {
        bool(forKey: "shouldCheckContactsAutomatically")
    }
}
#endif
