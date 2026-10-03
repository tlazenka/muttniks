//
//  Runtime.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

public final class _StateMachineIdentity: Equatable {
    public init() {}

    public static func == (lhs: _StateMachineIdentity, rhs: _StateMachineIdentity) -> Bool {
        lhs === rhs
    }
}

public final class _StateMachineStateOwner<State: ~Copyable> {
    private let storage: _StateMachineAtomicOneShot<State>
    public let identity: _StateMachineIdentity

    public init(_ state: consuming State) {
        identity = _StateMachineIdentity()
        storage = _StateMachineAtomicOneShot(consume state)
    }

    public var isAvailable: Bool {
        storage.isAvailable
    }

    public func take() -> State? {
        storage.take()
    }

    public func matches(_ other: borrowing _StateMachineStateOwner<State>) -> Bool {
        identity == other.identity
    }
}

public final class _StateMachineValueOwner<State> {
    private let state: State
    public let identity: _StateMachineIdentity

    public init(_ state: State) {
        self.state = state
        identity = _StateMachineIdentity()
    }

    public func value() -> State {
        state
    }

    public func matches(_ other: borrowing _StateMachineValueOwner<State>) -> Bool {
        identity == other.identity
    }
}
