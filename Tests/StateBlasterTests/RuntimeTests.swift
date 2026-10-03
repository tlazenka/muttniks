//
//  RuntimeTests.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import Testing

@testable import StateBlaster

private struct MoveOnlyValue: ~Copyable {
    let id: Int
}

@Test func stateOwnerHasStableIdentityAndOneShotOwnership() {
    let owner = _StateMachineStateOwner(MoveOnlyValue(id: 32))
    let same = owner
    let other = _StateMachineStateOwner(MoveOnlyValue(id: 7))

    #expect(owner.matches(same))
    #expect(!owner.matches(other))
    #expect(owner.isAvailable)

    let first = owner.take()
    switch consume first {
    case .some(let value):
        #expect(value.id == 32)
    case .none:
        Issue.record("Expected the first take to succeed")
    }

    #expect(!owner.isAvailable)

    let second = owner.take()
    switch consume second {
    case .some:
        Issue.record("Expected the second take to return nil")
    case .none:
        break
    }
}

@Test func valueOwnerHasStableIdentityWithoutOneShotConsumption() {
    let owner = _StateMachineValueOwner("verifying")
    let same = owner
    let other = _StateMachineValueOwner("verifying")

    #expect(owner.matches(same))
    #expect(!owner.matches(other))
    #expect(owner.value() == "verifying")
    #expect(owner.value() == "verifying")
}

@available(anyAppleOS 27.0, *)
@Test("UniqueBox lifecycle can borrow, mutate, then consume")
func uniqueBoxLifecycle() {
    struct Counter: ~Copyable {
        var value: Int
    }

    var box = UniqueBox(Counter(value: 1))
    let before = box.value.value
    box.value.value += 1
    let counter = box.consume()
    let result = before + counter.value
    #expect(result == 3)
}
