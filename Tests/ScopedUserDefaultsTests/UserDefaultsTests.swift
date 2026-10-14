//
//  UserDefaultsTests.swift
//  Racros
//
//  Created by Francis Lazenka on 9/24/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(Combine)

import Combine

@MainActor final class UserDefaultsTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    var userDefaults: UserDefaults!

    override func setUp() async throws {
        userDefaults = UserDefaults(suiteName: name)
        userDefaults.removePersistentDomain(forName: name)
    }

    func testBasics() async throws {
        var values = userDefaults.publisher(for: \.shouldCheckAutomatically)
            .buffer(size: .max, prefetch: .keepFull, whenFull: .dropOldest)
            .values
            .makeAsyncIterator()

        userDefaults.shouldCheckAutomatically = true

        let value1 = await values.next(isolation: #isolation)
        let value2 = await values.next(isolation: #isolation)

        XCTAssertEqual(value1, false)
        XCTAssertEqual(value2, true)
    }

    func testManual() async throws {
        var values = userDefaults.publisher(for: \.shouldCheckAutomatically)
            .buffer(size: .max, prefetch: .keepFull, whenFull: .dropOldest)
            .values
            .makeAsyncIterator()

        userDefaults.set(true, forKey: "shouldCheckAutomatically")

        let value1 = await values.next(isolation: #isolation)
        let value2 = await values.next(isolation: #isolation)

        XCTAssertEqual(value1, false)
        XCTAssertEqual(value2, true)
    }

    func testNaming() async throws {
        var values = userDefaults.publisher(for: \.shouldCheckAutomaticallyName1)
            .buffer(size: .max, prefetch: .keepFull, whenFull: .dropOldest)
            .values
            .makeAsyncIterator()

        userDefaults.set(true, forKey: "shouldCheckAutomaticallyName2")

        enum GroupResult {
            case values([Bool?])
            case timeout
        }

        let result = try await withThrowingTaskGroup(of: GroupResult.self) {
            $0.addTask {
                let value1 = await values.next(isolation: #isolation)
                let value2 = await values.next(isolation: #isolation)
                return .values([value1, value2])
            }
            $0.addTask {
                try await Task.sleep(for: .seconds(1))
                return .timeout
            }

            let result = try await $0.next()!
            $0.cancelAll()
            return result
        }

        let value =
            switch result {
            case .timeout:
                true
            case .values:
                false
            }

        XCTAssertTrue(value)
    }

}

extension UserDefaults {
    @objc dynamic var shouldCheckAutomatically: Bool {
        get {
            bool(forKey: "shouldCheckAutomatically")
        }
        set {
            set(newValue, forKey: "shouldCheckAutomatically")
        }
    }

    @objc dynamic var shouldCheckAutomaticallyName1: Bool {
        get {
            bool(forKey: "shouldCheckAutomaticallyName2")
        }
        set {
            set(newValue, forKey: "shouldCheckAutomaticallyName2")
        }
    }
}

#endif
