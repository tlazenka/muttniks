import Foundation

public enum QueryValue: Codable, Hashable, Sendable {
    case null
    case text(String)
    case integer(Int)
    case number(Double)
    case date(Date)
    case boolean(Bool)
}

public enum QueryStructure: String, Codable, Hashable, Sendable {
    case array
    case object
}

public enum QueryPredicate: Hashable, Sendable {
    case equals(field: String, value: QueryValue)
    case atLeast(field: String, value: QueryValue)
    case lessThan(field: String, value: QueryValue)
    case contains(field: String, value: String)
    case missing(field: String)
    case structure(field: String, QueryStructure)
    indirect case not(QueryPredicate)
    indirect case all([QueryPredicate])
    indirect case any([QueryPredicate])
}

private struct SendableKeyPath<Root, Value>: @unchecked Sendable {
    let value: KeyPath<Root, Value>

    init(_ value: KeyPath<Root, Value>) {
        self.value = value
    }
}

public enum QueryEvaluator {

}

public protocol QueryValueRepresentable: Sendable {
    var queryValue: QueryValue { get }
}

extension String: QueryValueRepresentable {
    public var queryValue: QueryValue {
        .text(self)
    }
}

extension Int: QueryValueRepresentable {
    public var queryValue: QueryValue {
        .integer(self)
    }
}

extension Double: QueryValueRepresentable {
    public var queryValue: QueryValue {
        .number(self)
    }
}

extension Bool: QueryValueRepresentable {
    public var queryValue: QueryValue {
        .boolean(self)
    }
}

extension Date: QueryValueRepresentable {
    public var queryValue: QueryValue {
        .date(self)
    }
}

extension UUID: QueryValueRepresentable {
    public var queryValue: QueryValue {
        .text(uuidString)
    }
}

extension URL: QueryValueRepresentable {
    public var queryValue: QueryValue {
        .text(absoluteString)
    }
}

extension Optional: QueryValueRepresentable where Wrapped: QueryValueRepresentable {
    public var queryValue: QueryValue {
        map { $0.queryValue } ?? .null
    }
}

public struct Field<Item: Sendable, Value: QueryValueRepresentable>: Sendable {
    public let id: String
    public let title: String
    public let choices: [String]?
    public let numericBounds: ClosedRange<Double>?
    public let integerBounds: ClosedRange<Int>?
    public let numericStep: Double?
    public let integerStep: Int?
    private let read: @Sendable (Item) -> Value

    init(
        id: String,
        title: String,
        choices: [String]? = nil,
        numericBounds: ClosedRange<Double>? = nil,
        integerBounds: ClosedRange<Int>? = nil,
        numericStep: Double? = nil,
        integerStep: Int? = nil,
        read: @escaping @Sendable (Item) -> Value
    ) {
        self.id = id
        self.title = title
        self.choices = choices
        self.numericBounds = numericBounds
        self.integerBounds = integerBounds
        self.numericStep = numericStep
        self.integerStep = integerStep
        self.read = read
    }

    public func value(in item: Item) -> Value {
        read(item)
    }

    public func equals(_ value: Value) -> QueryPredicate {
        .equals(field: id, value: value.queryValue)
    }

    static func keyPathName(_ keyPath: KeyPath<Item, Value>) -> String {
        String(describing: keyPath).split(separator: ".").last.map(String.init) ?? "field"
    }

    static func humanize(_ value: String) -> String { value.prefix(1).uppercased() + value.dropFirst() }

    static func defaultID(for title: String) -> String {
        title.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { result, character in
                if character != "-" || result.last != "-" { result.append(character) }
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

public extension Field where Value == String {
    init(_ title: String, _ keyPath: KeyPath<Item, String>, id: String? = nil, values: [String]) {
        let keyPath = SendableKeyPath(keyPath)
        self.init(id: id ?? Self.defaultID(for: title), title: title, choices: values) { $0[keyPath: keyPath.value] }
    }

    init(_ keyPath: KeyPath<Item, String>, values: [String]) {
        let name = Self.keyPathName(keyPath)
        self.init(Self.humanize(name), keyPath, id: name, values: values)
    }

    func contains(_ text: String) -> QueryPredicate {
        .contains(field: id, value: text)
    }
}

public extension Field where Value == Int {
    init(_ title: String, _ keyPath: KeyPath<Item, Int>, id: String? = nil, range: ClosedRange<Int>, step: Int = 1) {
        let keyPath = SendableKeyPath(keyPath)
        self.init(id: id ?? Self.defaultID(for: title), title: title, integerBounds: range, integerStep: step) {
            $0[keyPath: keyPath.value]
        }
    }

    init(_ keyPath: KeyPath<Item, Int>, range: ClosedRange<Int>, step: Int = 1) {
        let name = Self.keyPathName(keyPath)
        self.init(Self.humanize(name), keyPath, id: name, range: range, step: step)
    }

    func atLeast(_ value: Int) -> QueryPredicate {
        .atLeast(field: id, value: value.queryValue)
    }

    func lessThan(_ value: Int) -> QueryPredicate {
        .lessThan(field: id, value: value.queryValue)
    }
}

public extension Field where Value == Double {
    init(
        _ title: String,
        _ keyPath: KeyPath<Item, Double>,
        id: String? = nil,
        range: ClosedRange<Double>,
        step: Double = 0.1
    ) {
        let keyPath = SendableKeyPath(keyPath)
        self.init(id: id ?? Self.defaultID(for: title), title: title, numericBounds: range, numericStep: step) {
            $0[keyPath: keyPath.value]
        }
    }

    init(_ keyPath: KeyPath<Item, Double>, range: ClosedRange<Double>, step: Double = 0.1) {
        let name = Self.keyPathName(keyPath)
        self.init(Self.humanize(name), keyPath, id: name, range: range, step: step)
    }

    func atLeast(_ value: Double) -> QueryPredicate {
        .atLeast(field: id, value: value.queryValue)
    }

    func lessThan(_ value: Double) -> QueryPredicate {
        .lessThan(field: id, value: value.queryValue)
    }
}

public extension Field where Value == String? {
    init(_ title: String, _ keyPath: KeyPath<Item, String?>, id: String? = nil, values: [String]) {
        let keyPath = SendableKeyPath(keyPath)
        self.init(id: id ?? Self.defaultID(for: title), title: title, choices: values) { $0[keyPath: keyPath.value] }
    }
}

public extension Field where Value == Int? {
    init(_ title: String, _ keyPath: KeyPath<Item, Int?>, id: String? = nil, range: ClosedRange<Int>, step: Int = 1) {
        let keyPath = SendableKeyPath(keyPath)
        self.init(id: id ?? Self.defaultID(for: title), title: title, integerBounds: range, integerStep: step) {
            $0[keyPath: keyPath.value]
        }
    }

    func atLeast(_ value: Int) -> QueryPredicate {
        .atLeast(field: id, value: .integer(value))
    }

    func lessThan(_ value: Int) -> QueryPredicate {
        .lessThan(field: id, value: .integer(value))
    }
}

public extension Field where Value == Double? {
    init(
        _ title: String,
        _ keyPath: KeyPath<Item, Double?>,
        id: String? = nil,
        range: ClosedRange<Double>,
        step: Double = 0.1
    ) {
        let keyPath = SendableKeyPath(keyPath)
        self.init(id: id ?? Self.defaultID(for: title), title: title, numericBounds: range, numericStep: step) {
            $0[keyPath: keyPath.value]
        }
    }

    func atLeast(_ value: Double) -> QueryPredicate {
        .atLeast(field: id, value: .number(value))
    }

    func lessThan(_ value: Double) -> QueryPredicate {
        .lessThan(field: id, value: .number(value))
    }
}

public extension Field where Value == Date? {
    init(_ title: String, _ keyPath: KeyPath<Item, Date?>, id: String? = nil) {
        let keyPath = SendableKeyPath(keyPath)
        self.init(id: id ?? Self.defaultID(for: title), title: title) { $0[keyPath: keyPath.value] }
    }

    init(_ keyPath: KeyPath<Item, Date?>) {
        let name = Self.keyPathName(keyPath)
        self.init(Self.humanize(name), keyPath, id: name)
    }
}
