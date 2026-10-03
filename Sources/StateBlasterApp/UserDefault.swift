import Foundation

// see https://dev.to/kodelit/userdefaults-property-wrapper-issues-solutions-4lk9

/*
MIT License

Copyright (c) 2019 kodelit

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

@propertyWrapper
public struct UserDefault<Value: RawRepresentable> where Value.RawValue == String {
    public let key: String
    public let store: UserDefaults

    public var wrappedValue: Value? {
        get {
            guard let value = store.object(forKey: key) as? Value.RawValue else {
                return nil
            }
            return Value(rawValue: value)
        }
        set {
            store.set(newValue?.rawValue, forKey: key)
        }
    }
}

extension String: RawRepresentable {
    public var rawValue: String {
        self
    }

    public init?(rawValue: String) {
        self = rawValue
    }
}

@propertyWrapper
public struct BoolUserDefault<Value: RawRepresentable> where Value.RawValue == Bool {
    public let key: String
    public let store: UserDefaults

    public var wrappedValue: Bool {
        get {
            store.bool(forKey: key)
        }
        set {
            store.set(newValue.rawValue, forKey: key)
        }
    }

    public init(
        key: String,
        defaultValue: Value,
        store: UserDefaults
    ) {
        self.key = key
        self.store = store

        store.register(defaults: [key: defaultValue])
    }
}

extension Bool: RawRepresentable {
    public var rawValue: Bool {
        self
    }

    public init?(rawValue: Bool) {
        self = rawValue
    }
}
