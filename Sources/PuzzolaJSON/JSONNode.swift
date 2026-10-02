//
//  JSONNode.swift
//  Puzzola
//
//  Created by Francis Lazenka on 10/1/26.
//

import CoreFoundation
import Foundation

public struct JSONNode: Identifiable {
    public enum Value {
        case object
        case array
        case string(String)
        case number(String)
        case bool(Bool)
        case null
    }

    public let id: String
    public let name: String
    public let path: String
    public let value: Value
    public let children: [JSONNode]

    public var summary: String {
        switch value {
        case .object: "{\(children.count)}"
        case .array: "[\(children.count)]"
        case .string(let value): "\"\(value)\""
        case .number(let value): value
        case .bool(let value): value ? "true" : "false"
        case .null: "null"
        }
    }

    public func filtering(_ search: String) -> JSONNode? {
        let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else {
            return self
        }

        let filteredChildren = children.compactMap {
            $0.filtering(search)
        }

        let matches =
            name.localizedCaseInsensitiveContains(search) || path.localizedCaseInsensitiveContains(search)
            || summary.localizedCaseInsensitiveContains(search)

        guard matches || !filteredChildren.isEmpty else {
            return nil
        }

        return JSONNode(
            id: id,
            name: name,
            path: path,
            value: value,
            children: filteredChildren
        )
    }

    public static func loadEarthquakes() throws -> JSONNode {
        guard
            let url = Bundle.main.url(
                forResource: "SampleData",
                withExtension: "json"
            )
        else {
            throw CocoaError(.fileNoSuchFile)
        }

        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(
            with: data,
            options: [.fragmentsAllowed]
        )
        return make(name: "$", path: "$", value: object)
    }

    public static func make(
        name: String,
        path: String,
        value: Any
    ) -> JSONNode {
        if let object = value as? [String: Any] {
            let children: [JSONNode] = object.keys.sorted().compactMap { key in
                guard
                    let value = object[key]
                else {
                    assertionFailure()
                    return nil
                }
                return make(
                    name: key,
                    path: memberPath(path, key),
                    value: value
                )
            }
            return JSONNode(id: path, name: name, path: path, value: .object, children: children)
        }

        if let array = value as? [Any] {
            let children = array.enumerated().map { index, value in
                make(
                    name: "[\(index)]",
                    path: "\(path)[\(index)]",
                    value: value
                )
            }
            return JSONNode(id: path, name: name, path: path, value: .array, children: children)
        }

        if value is NSNull {
            return JSONNode(id: path, name: name, path: path, value: .null, children: [])
        }

        if let string = value as? String {
            return JSONNode(id: path, name: name, path: path, value: .string(string), children: [])
        }

        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return JSONNode(id: path, name: name, path: path, value: .bool(number.boolValue), children: [])
            }
            return JSONNode(
                id: path,
                name: name,
                path: path,
                value: .number(number.stringValue),
                children: []
            )
        }

        return JSONNode(
            id: path,
            name: name,
            path: path,
            value: .string(String(describing: value)),
            children: []
        )
    }

    public static func memberPath(_ base: String, _ key: String) -> String {
        let simple =
            !key.isEmpty
            && key.allSatisfy {
                $0.isLetter || $0.isNumber || $0 == "_"
            }
        return simple ? "\(base).\(key)" : "\(base).\(key)"
    }
}

public extension JSONNode {
    func node(atRelativePath path: String) -> JSONNode? {
        guard path.first == "$" else { return nil }
        var current = self
        var remaining = path.dropFirst()
        while !remaining.isEmpty {
            if remaining.first == "." {
                remaining.removeFirst()
                let name = remaining.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                guard !name.isEmpty, let child = current.children.first(where: { $0.name == String(name) }) else {
                    return nil
                }
                current = child
                remaining.removeFirst(name.count)
            } else if remaining.first == "[" {
                guard let close = remaining.firstIndex(of: "]"),
                    let index = Int(remaining[remaining.index(after: remaining.startIndex)..<close]),
                    current.children.indices.contains(index)
                else { return nil }
                current = current.children[index]
                remaining = remaining[remaining.index(after: close)...]
            } else {
                return nil
            }
        }
        return current
    }

    func filtering(_ filter: FieldFilter) -> JSONNode? {
        if path == "$.features" {
            let matches = children.filter { feature in
                switch filter {
                case .minimum(let path, let threshold, _):
                    guard let node = feature.node(atRelativePath: path), case .number(let text) = node.value,
                        let value = Double(text)
                    else { return false }
                    return value >= threshold
                case .category(let path, let selected, _):
                    guard let node = feature.node(atRelativePath: path) else { return false }
                    switch node.value {
                    case .string(let value): return value == selected
                    case .bool(let value): return (value ? "true" : "false") == selected
                    default: return false
                    }
                }
            }
            return JSONNode(id: id, name: name, path: path, value: value, children: matches)
        }
        let filtered = children.compactMap { $0.filtering(filter) }
        guard !filtered.isEmpty else { return nil }
        return JSONNode(id: id, name: name, path: path, value: value, children: filtered)
    }
}
