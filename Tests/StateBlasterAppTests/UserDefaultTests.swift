import Foundation
import XCTest

@testable import StateBlaster
@testable import StateBlasterApp

@MainActor public class UserDefaultTests: XCTestCase {
    var userDefaults: UserDefaults!

    public override func setUp() async throws {
        userDefaults = UserDefaults(suiteName: name)
        userDefaults.removePersistentDomain(forName: name)
    }

    @MainActor final class DataManager {
        @UserDefault var phoneNumber: PhoneNumber?
        @UserDefault var userId: UserId?
        @UserDefault public var deviceToken: String?

        public init(userDefaults: UserDefaults) {
            _userId = .init(key: "userId", store: userDefaults)
            _phoneNumber = .init(key: "phoneNumber", store: userDefaults)
            _deviceToken = .init(key: "deviceToken", store: userDefaults)
        }
    }

    func testUserDefaults() {
        let dataManager = DataManager(userDefaults: userDefaults)

        XCTAssertNil(userDefaults.object(forKey: "userId"))
        XCTAssertNil(userDefaults.object(forKey: "phoneNumber"))
        XCTAssertNil(userDefaults.object(forKey: "deviceToken"))

        dataManager.userId = UserId(value: UUID(uuidString: "EE6FF82C-6645-4B81-9160-1D7E3BA3C999")!)
        dataManager.phoneNumber = PhoneNumber(value: "123456")
        dataManager.deviceToken = "abc"

        XCTAssertEqual(userDefaults.string(forKey: "userId"), "EE6FF82C-6645-4B81-9160-1D7E3BA3C999")
        XCTAssertEqual(userDefaults.string(forKey: "phoneNumber"), "123456")
        XCTAssertEqual(userDefaults.string(forKey: "deviceToken"), "abc")

        dataManager.userId = nil
        dataManager.phoneNumber = nil
        dataManager.deviceToken = nil

        XCTAssertNil(userDefaults.object(forKey: "userId"))
        XCTAssertNil(userDefaults.object(forKey: "phoneNumber"))
        XCTAssertNil(userDefaults.object(forKey: "deviceToken"))
    }
}
