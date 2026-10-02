//
//  JSONNode+UI.swift
//  Puzzola
//
//  Created by Francis Lazenka on 10/1/26.
//

import CoreFoundation
import Foundation

public func dockerCommand(for filter: FieldFilter) -> String {
    let expression: String
    switch filter {
    case .minimum(let path, let value, _):
        expression = "\(path) >= \(value)"
    case .category(let path, let value, _):
        expression = "\(path) = \"\(escapeQueryString(value))\""
    }

    return "docker compose run --rm earthquakes \(shellQuote(expression))"
}

public func escapeQueryString(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

public func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
}

public struct JSONNodeViewModel {
    let root: JSONNode

    public init(root: JSONNode) {
        self.root = root
    }

    public func collectCategoricalNames(in node: JSONNode, into names: inout Set<String>) {
        switch node.value {
        case .string, .bool:
            names.insert(node.name)
        default:
            break
        }
        for child in node.children {
            collectCategoricalNames(in: child, into: &names)
        }
    }

    public func categoricalValues(named fieldName: String) -> [String] {
        var values = Set<String>()
        for feature in featureNodes() {
            collectCategoricalValues(named: fieldName, in: feature, into: &values)
        }
        return values.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    public func collectCategoricalValues(
        named fieldName: String,
        in node: JSONNode,
        into values: inout Set<String>
    ) {
        if node.name == fieldName {
            switch node.value {
            case .string(let value):
                values.insert(value)
            case .bool(let value):
                values.insert(value ? "true" : "false")
            default:
                break
            }
        }
        for child in node.children {
            collectCategoricalValues(named: fieldName, in: child, into: &values)
        }
    }

    public func facetedResultCount(fieldName: String, value: String) -> Int {
        featureNodes().filter { $0.containsCategorical(name: fieldName, value: value) }.count
    }

    public func collectCategoricalFields(
        in node: JSONNode,
        valuesByPath: inout [String: Set<String>],
        namesByPath: inout [String: String]
    ) {
        if let path = featureRelativePath(from: node.path) {
            switch node.value {
            case .string(let value):
                valuesByPath[path, default: []].insert(value)
                namesByPath[path] = node.name
            case .bool(let value):
                valuesByPath[path, default: []].insert(value ? "true" : "false")
                namesByPath[path] = node.name
            default:
                break
            }
        }
        for child in node.children {
            collectCategoricalFields(in: child, valuesByPath: &valuesByPath, namesByPath: &namesByPath)
        }
    }

    public func fieldName(for path: String) -> String {
        path.split(separator: ".").last.map(String.init) ?? path
    }

    public func initialFilter(path: String, value: JSONNode.Value) -> FieldFilter? {
        switch value {
        case .number(let text):
            guard let value = Double(text) else { return nil }
            return .minimum(path: path, value: value, values: numericValues(at: path))
        case .string(let value):
            return .category(path: path, value: value, values: stringValues(at: path))
        case .bool(let value):
            let values = scalarValues(at: path).compactMap {
                if case .bool(let v) = $0 { return v ? "true" : "false" }; return nil
            }
            return .category(path: path, value: value ? "true" : "false", values: Array(Set(values)).sorted())
        case .null, .object, .array:
            return nil
        }
    }

    public func adjusted(_ filter: FieldFilter, translationX: CGFloat) -> FieldFilter {
        let steps = Int((translationX / 28).rounded())
        switch filter {
        case .minimum(let path, let value, let values):
            guard let start = values.nearestIndex(to: value), !values.isEmpty else { return filter }
            let index = min(max(start + steps, 0), values.count - 1)
            return .minimum(path: path, value: values[index], values: values)
        case .category(let path, let value, let values):
            guard let start = values.firstIndex(of: value), !values.isEmpty else { return filter }
            let index = min(max(start + steps, 0), values.count - 1)
            return .category(path: path, value: values[index], values: values)
        }
    }

    public func featureRelativePath(from path: String) -> String? {
        guard path.hasPrefix("$.features["), let close = path.firstIndex(of: "]") else { return nil }
        let suffix = path[path.index(after: close)...]
        return suffix.isEmpty ? nil : "$" + suffix
    }

    public func featureNodes() -> [JSONNode] {
        root.children.first(where: { $0.name == "features" })?.children ?? []
    }
    public func scalarValues(at path: String) -> [JSONNode.Value] {
        featureNodes().compactMap { $0.node(atRelativePath: path)?.value }
    }
    public func numericValues(at path: String) -> [Double] {
        Array(
            Set(
                scalarValues(at: path).compactMap {
                    if case .number(let s) = $0 { return Double(s) }; return nil
                }
            )
        ).sorted()
    }
    public func stringValues(at path: String) -> [String] {
        Array(
            Set(
                scalarValues(at: path).compactMap {
                    if case .string(let s) = $0 { return s }; return nil
                }
            )
        ).sorted()
    }
}

public enum FieldFilter: Equatable {
    case minimum(path: String, value: Double, values: [Double])
    case category(path: String, value: String, values: [String])

    public var description: String {
        switch self {
        case .minimum(let path, let value, _): "\(path) ≥ \(value.formatted())"
        case .category(let path, let value, _): "\(path) = \(value)"
        }
    }
}

public extension FieldFilter {
    var path: String {
        switch self {
        case .minimum(let path, _, _), .category(let path, _, _):
            return path
        }
    }

    var analyticsProperties: [String: Any] {
        switch self {
        case .minimum(let path, let value, _):
            return ["path": path, "kind": "numeric", "value": value]
        case .category(let path, let value, _):
            return ["path": path, "kind": "categorical", "value": value]
        }
    }
}

public extension JSONNode.Value {
    var analyticsKind: String {
        switch self {
        case .number: return "numeric"
        case .string, .bool: return "categorical"
        case .null: return "null"
        case .object: return "object"
        case .array: return "array"
        }
    }
}

public extension Array where Element == Double {
    func nearestIndex(to value: Double) -> Int? { indices.min { abs(self[$0] - value) < abs(self[$1] - value) } }
}
