import Foundation

@available(anyAppleOS 27.0, *)
public final class _StateMachineUniqueBoxOneShot<Value: ~Copyable> {
    private let lock = NSLock()
    private var box: UniqueBox<Value>?

    public init(_ value: consuming Value) {
        box = UniqueBox(consume value)
    }

    public var isAvailable: Bool {
        lock.withLock {
            box != nil
        }
    }

    public func take() -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let box = box.take() else {
            return nil
        }
        return box.consume()
    }
}

#if compiler(>=6.4)
@available(anyAppleOS 27.0, *)
public func _stateMachineUniqueBoxLifecycleExperiment() -> Int {
    struct Counter: ~Copyable {
        var value: Int
    }

    var box = UniqueBox(Counter(value: 1))
    let before = box.value.value
    box.value.value += 1
    let counter = box.consume()
    return before + counter.value
}
#endif
