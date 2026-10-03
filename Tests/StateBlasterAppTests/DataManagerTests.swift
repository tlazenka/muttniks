import Foundation
import XCTest

@testable import StateBlasterApp

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(CoreData)

@MainActor public class DataManagerTests: XCTestCase {
    var userDefaults: UserDefaults!

    public override func setUp() async throws {
        userDefaults = UserDefaults(suiteName: name)
        userDefaults.removePersistentDomain(forName: name)
    }

    func testCreateUser() async throws {
        let urlSessionConfiguration = URLSessionConfiguration.ephemeral
        let requestHandler = RequestHandler()
        URLProtocolMock.requestHandler = requestHandler.handleRequest
        urlSessionConfiguration.protocolClasses = [URLProtocolMock.self]

        let dataManager = DoorDataManager<
            AuthenticatorMock.GetCredentialResult, SignInResultMock, String, AuthenticatorMock
        >(
            coreDataManager: DoorCoreDataManager(persistentStoreType: .inMemory),
            remoteDataManager: .makeMock(urlSessionConfiguration: urlSessionConfiguration),
            authenticator: AuthenticatorMock(),
            userDefaults: userDefaults,
            notificationCenter: NotificationCenter(),
            blobCache: .init()
        )

        let createdUser = try await dataManager.createUser(timeOffsetMinutes: 0)

        XCTAssertEqual(createdUser.id, UUID(uuidString: "EE6FF82C-6645-4B81-9160-1D7E3BA3C999")!)
    }

    func testUserDefaults() throws {
        let urlSessionConfiguration = URLSessionConfiguration.ephemeral
        let requestHandler = RequestHandler()
        URLProtocolMock.requestHandler = requestHandler.handleRequest
        urlSessionConfiguration.protocolClasses = [URLProtocolMock.self]

        let dataManager = DoorDataManager<
            AuthenticatorMock.GetCredentialResult, SignInResultMock, String, AuthenticatorMock
        >(
            coreDataManager: DoorCoreDataManager(persistentStoreType: .inMemory),
            remoteDataManager: .makeMock(urlSessionConfiguration: urlSessionConfiguration),
            authenticator: AuthenticatorMock(),
            userDefaults: userDefaults,
            notificationCenter: NotificationCenter(),
            blobCache: .init()
        )

        XCTAssertNil(dataManager.userId)
        XCTAssertNil(dataManager.phoneNumber)

        let userId = UserId(value: UUID(uuidString: "EE6FF82C-6645-4B81-9160-1D7E3BA3C999")!)
        dataManager.userId = userId
        XCTAssertEqual(dataManager.userId, userId)

        dataManager.phoneNumber = PhoneNumber(value: "123456")
        XCTAssertEqual(dataManager.phoneNumber, PhoneNumber(value: "123456"))

        dataManager.userId = nil
        XCTAssertNil(dataManager.userId)

        dataManager.phoneNumber = nil
        XCTAssertNil(dataManager.phoneNumber)
    }

    func testContactAvailability() async throws {
        let urlSessionConfiguration = URLSessionConfiguration.ephemeral
        let requestHandler = RequestHandler()
        URLProtocolMock.requestHandler = requestHandler.handleRequest
        urlSessionConfiguration.protocolClasses = [URLProtocolMock.self]

        let dataManager = DoorDataManager<
            AuthenticatorMock.GetCredentialResult, SignInResultMock, String, AuthenticatorMock
        >(
            coreDataManager: DoorCoreDataManager(persistentStoreType: .inMemory),
            remoteDataManager: .makeMock(urlSessionConfiguration: urlSessionConfiguration),
            authenticator: AuthenticatorMock(),
            userDefaults: userDefaults,
            notificationCenter: NotificationCenter(),
            blobCache: .init()
        )

        let contactAvailability = try await dataManager.getUsers(
            phoneNumbers: [
                PhoneNumber(value: "1"),
                PhoneNumber(value: "2"),
                PhoneNumber(value: "3"),
                PhoneNumber(value: "4"),
            ],
            addingCnContactIdentifier: ""
        )
        XCTAssertTrue(
            contactAvailability.contains(where: {
                $0.phoneNumber == "2"
            })
        )
        XCTAssertFalse(
            contactAvailability.contains(where: {
                $0.phoneNumber == "1"
            })
        )
        XCTAssertFalse(
            contactAvailability.contains(where: {
                $0.phoneNumber == "3"
            })
        )
        XCTAssertFalse(
            contactAvailability.contains(where: {
                $0.phoneNumber == "4"
            })
        )
    }

    func testUserDecoding() throws {
        let userJson = try Bundle.module.stringFromResource(withName: "user.json", type: nil)
        let userData = try XCTUnwrap(userJson.data(using: .utf8))
        let decodedUser = try JSONDecoder.doorJsonDecoder.decode(RemoteUser.self, from: userData)
        XCTAssertNotNil(decodedUser)
    }
}

extension DataManagerTests {
    @MainActor final class RequestHandler {
        let lock = NSLock()
        var requests = [URLRequest]()
        var requestCount = 0

        func handleRequest(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
            lock.lock()
            requestCount += 1
            requests.append(request)
            lock.unlock()

            let url = try XCTUnwrap(URL(string: "http://example.com/user"))
            let response = try XCTUnwrap(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )

            let data: Data
            if request.httpMethod == "POST",
                let urlString = request.url?.absoluteString,
                urlString.starts(with: "mock/api/users/check")
            {
                data = try JSONEncoder().encode(
                    [
                        ApiGetUserResponse(
                            id: UUID(uuidString: "EE6FF82C-6645-4B81-9160-1D7E3BA3C999")!,
                            phoneNumber: "2",
                            hashedPhoneNumber: "2",
                            doorId: nil,
                            customDoorId: nil,
                            imageFilterNextAvailableDate: nil
                        )
                    ]
                )
            } else if request.httpMethod == "POST",
                let urlString = request.url?.absoluteString,
                urlString.starts(with: "mock/api/user")
            {
                data = try JSONEncoder().encode(
                    ApiPostUserResponse(id: UUID(uuidString: "EE6FF82C-6645-4B81-9160-1D7E3BA3C999")!)
                )
            } else {
                data = Data()
                XCTFail("Unexpected request")
            }

            return (response, data)
        }
    }
}

#endif
