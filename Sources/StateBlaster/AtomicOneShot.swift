//
//  AtomicOneShot.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import Foundation

public final class _StateMachineAtomicOneShot<Value: ~Copyable> {
    private let lock = NSLock()
    private var value: Value?

    public init(_ value: consuming Value) {
        self.value = consume value
    }

    public var isAvailable: Bool {
        lock.withLock {
            value != nil
        }
    }

    public func take() -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return value.take()
    }
}
