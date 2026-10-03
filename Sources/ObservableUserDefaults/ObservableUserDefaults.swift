//
//  ObservableUserDefaults.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import Foundation

#if canImport(Combine)
import Combine
#endif

@attached(accessor, names: named(get), named(set))
public macro DefaultKey(_ key: String? = nil) =
    #externalMacro(
        module: "ObservableUserDefaultsMacros",
        type: "DefaultKeyMacro"
    )

@attached(peer)
public macro Registered<T>(_ value: T) =
    #externalMacro(
        module: "ObservableUserDefaultsMacros",
        type: "RegisteredMacro"
    )

@attached(
    member,
    names: named(_unsafeDefaults),
    named(init),
    named(Keys),
    named(keys),
    named(registrationDefaults),
    named(register)
)
@attached(memberAttribute)
@attached(extension, conformances: DefaultsScope)
public macro Defaults(_ store: DefaultsStore = .standard) =
    #externalMacro(
        module: "ObservableUserDefaultsMacros",
        type: "DefaultsMacro"
    )

public enum DefaultsStore: Sendable {
    case standard
    case named(String)
}

public protocol DefaultsScope {
    init(defaults: UserDefaults)
    static var keys: Set<String> { get }
    static var registrationDefaults: [String: Any] { get }
    var _unsafeDefaults: UserDefaults { get }
}

public extension DefaultsScope {
    func register() {
        _unsafeDefaults.register(defaults: Self.registrationDefaults)
    }
}

#if canImport(Combine) && canImport(ObjectiveC)
public extension DefaultsScope {
    var didChangePublisher: some Publisher<Void, Never> {
        _unsafeDefaults.didChangePublisher
    }

    func didChangePublisher<Value>(
        for keyPath: KeyPath<Self, Value>
    ) -> some Publisher<Value, Never> {
        _unsafeDefaults.didChangePublisher.map { self[keyPath: keyPath] }
    }
}
#endif

private func validateNoDuplicateKeys(_ scopes: [(Any.Type, Set<String>)]) {
    var owners: [String: Any.Type] = [:]
    for (scope, keys) in scopes {
        for key in keys {
            if let existing = owners[key] {
                preconditionFailure(
                    "Key '\(key)' already in the store"
                )
            }
            owners[key] = scope
        }
    }
}

public struct Defaults<Scope: DefaultsScope> {
    public let _unsafeDefaults: UserDefaults
    public init(store: UserDefaults) {
        self._unsafeDefaults = store
    }
    public func callAsFunction(_ type: Scope.Type = Scope.self) -> Scope {
        Scope(defaults: _unsafeDefaults)
    }
    public func register() {
        _unsafeDefaults.register(defaults: Scope.registrationDefaults)
    }
    public var registrationDefaults: [String: Any] { Scope.registrationDefaults }
}

public struct Defaults2<A: DefaultsScope, B: DefaultsScope> {
    public let _unsafeDefaults: UserDefaults
    public init(store: UserDefaults) {
        validateNoDuplicateKeys([(A.self, A.keys), (B.self, B.keys)])
        self._unsafeDefaults = store
    }
    public func callAsFunction(_ type: A.Type) -> A { A(defaults: _unsafeDefaults) }
    public func callAsFunction(_ type: B.Type) -> B { B(defaults: _unsafeDefaults) }
    public var registrationDefaults: [String: Any] {
        A.registrationDefaults.merging(B.registrationDefaults) { first, _ in first }
    }
    public func register() { _unsafeDefaults.register(defaults: registrationDefaults) }
}

public struct Defaults3<A: DefaultsScope, B: DefaultsScope, C: DefaultsScope> {
    public let _unsafeDefaults: UserDefaults
    public init(store: UserDefaults) {
        validateNoDuplicateKeys([(A.self, A.keys), (B.self, B.keys), (C.self, C.keys)])
        self._unsafeDefaults = store
    }
    public func callAsFunction(_ type: A.Type) -> A { A(defaults: _unsafeDefaults) }
    public func callAsFunction(_ type: B.Type) -> B { B(defaults: _unsafeDefaults) }
    public func callAsFunction(_ type: C.Type) -> C { C(defaults: _unsafeDefaults) }
    public var registrationDefaults: [String: Any] {
        A.registrationDefaults
            .merging(B.registrationDefaults) { first, _ in first }
            .merging(C.registrationDefaults) { first, _ in first }
    }
    public func register() { _unsafeDefaults.register(defaults: registrationDefaults) }
}

public extension UserDefaults {
    func providing<A: DefaultsScope>(_ a: A.Type) -> Defaults<A> {
        Defaults(store: self)
    }

    func providing<A: DefaultsScope, B: DefaultsScope>(
        _ a: A.Type,
        _ b: B.Type
    ) -> Defaults2<A, B> {
        Defaults2(store: self)
    }

    func providing<A: DefaultsScope, B: DefaultsScope, C: DefaultsScope>(
        _ a: A.Type,
        _ b: B.Type,
        _ c: C.Type
    ) -> Defaults3<A, B, C> {
        Defaults3(store: self)
    }

}

#if canImport(Combine) && canImport(ObjectiveC)
public extension UserDefaults {
    func values<Value>(
        for keyPath: KeyPath<UserDefaults, Value>,
        options: NSKeyValueObservingOptions = []
    ) -> AsyncPublisher<KeyValueObservingPublisher<UserDefaults, Value>> {
        publisher(for: keyPath, options: options).values
    }

    var didChangePublisher: some Publisher<Void, Never> {
        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: self)
            .map { _ in () }
    }

    func didChangePublisher<Value>(
        for keyPath: KeyPath<UserDefaults, Value>
    ) -> some Publisher<Value, Never> {
        didChangePublisher.map { self[keyPath: keyPath] }
    }
}
#endif
