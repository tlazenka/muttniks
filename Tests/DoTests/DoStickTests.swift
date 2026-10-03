//
//  DoTests.swift
//  Racros
//
//  Created by Francis Lazenka on 9/24/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@MainActor final class DoStickTests: XCTestCase {
    fileprivate var service: ServiceProtocol!

    override func setUp() async throws {
        service = ServiceMock()
    }

    func testBasics() async throws {
        func fetchCurrentUser() -> Result<(User, Door), ServiceFailure> {
            switch service.fetchUser() {
            case .success(let user):
                switch service.fetchDoor(for: user.id) {
                case .success(let door):
                    .success((user, door))
                case .failure(let failure):
                    .failure(failure)
                }
            case .failure(let failure):
                .failure(failure)
            }
        }
        switch fetchCurrentUser() {
        case .failure(let failure):
            XCTFail(failure.localizedDescription)
        case .success((_, _)):
            break
        }
    }
}

private enum ServiceFailure: Error {

}

private struct UserID {
    let rawValue: UUID
}

private struct DoorID {
    let rawValue: UUID
}

private struct User {
    let id: UserID
}

private struct Door {
    let id: DoorID
}

private protocol ServiceProtocol {
    func fetchUser() -> Result<User, ServiceFailure>

    func fetchDoor(for userID: UserID) -> Result<Door, ServiceFailure>
}

private final class ServiceMock: ServiceProtocol {
    func fetchUser() -> Result<User, ServiceFailure> {
        .success(User(id: UserID(rawValue: UUID())))
    }

    func fetchDoor(for userID: UserID) -> Result<Door, ServiceFailure> {
        .success(Door(id: DoorID(rawValue: UUID())))
    }

}
