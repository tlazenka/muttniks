//
//  AtomicOneShotTests.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import Foundation
import Testing

@testable import StateBlaster

@Suite("Atomic one-shot runtime")
struct AtomicOneShotTests {
    struct Token: ~Copyable {
        let value: Int
    }

    @Test("take succeeds exactly once")
    func takeOnce() {
        let storage = _StateMachineAtomicOneShot(Token(value: 32))
        #expect(storage.isAvailable)

        let first = storage.take()
        switch consume first {
        case .some(let value):
            #expect(value.value == 32)
        case .none:
            Issue.record("Expected the first take to succeed")
        }
        #expect(!storage.isAvailable)

        let second = storage.take()
        switch consume second {
        case .some:
            Issue.record("Expected the second take to return nil")
        case .none:
            break
        }
    }

    @Test("concurrent callers have one winner")
    func concurrentTake() {
        let storage = _StateMachineAtomicOneShot(1)
        let winners = NSLock()
        var winnerCount = 0

        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            if storage.take() != nil {
                winners.lock()
                winnerCount += 1
                winners.unlock()
            }
        }

        #expect(winnerCount == 1)
        #expect(!storage.isAvailable)
    }
}

@available(anyAppleOS 27.0, *)
@Test
func uniqueBoxOneShotPrototypeTransfersMoveOnlyValueExactlyOnce() {
    struct MoveOnlyToken: ~Copyable {
        let value: Int
    }

    let storage = _StateMachineUniqueBoxOneShot(MoveOnlyToken(value: 64))
    #expect(storage.isAvailable)

    switch storage.take() {
    case .some(let token):
        #expect(token.value == 64)
    case .none:
        Issue.record("Expected the first take to succeed")
    }

    #expect(!storage.isAvailable)

    switch storage.take() {
    case .some:
        Issue.record("Expected the second take to return nil")
    case .none:
        break
    }
}
