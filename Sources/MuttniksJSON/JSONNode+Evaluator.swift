//
//  JSONNode+Evaluator.swift
//  Muttniks
//
//  Created by Francis Lazenka on 10/1/26.
//

import Muttniks
import MuttniksParsers

extension JSONNode {
    func filtering(expression source: String) throws -> JSONNode? {
        let expression = try parseQueryExpression(source)
        return filteringFeatures(matching: expression)
    }

    func filteringFeatures(matching expression: MuttniksParsers.Expression) -> JSONNode? {
        if path == "$.features" {
            let matches = children.filter { $0.matches(expression) }
            guard !matches.isEmpty else { return nil }
            return replacingChildren(matches)
        }

        let filteredChildren = children.compactMap {
            $0.filteringFeatures(matching: expression)
        }
        guard !filteredChildren.isEmpty else { return nil }
        return replacingChildren(filteredChildren)
    }

    func matches(_ expression: MuttniksParsers.Expression) -> Bool {
        return switch expression {
        case .comparison(let comparison):
            compare(node(atRelativePath: comparison.path), using: comparison)

        case .and(let lhs, let rhs):
            matches(lhs) && matches(rhs)

        case .or(let lhs, let rhs):
            matches(lhs) || matches(rhs)
        }
    }

    func compare(_ node: JSONNode?, using comparison: MuttniksParsers.Comparison) -> Bool {
        guard let node else { return false }

        switch comparison.value {
        case .number(let rhs):
            guard let lhs = node.numberValue else { return false }
            return compare(lhs, rhs, using: comparison.operation)

        case .string(let rhs):
            guard case .string(let lhs) = node.value else { return false }
            return compare(lhs, rhs, using: comparison.operation)

        case .bool(let rhs):
            guard case .bool(let lhs) = node.value else { return false }
            return comparison.operation == .equal ? lhs == rhs : comparison.operation == .notEqual ? lhs != rhs : false

        case .null:
            let isNull: Bool
            if case .null = node.value { isNull = true } else { isNull = false }
            return comparison.operation == .notEqual ? !isNull : isNull
        }
    }

    func compare<T: Comparable>(
        _ lhs: T,
        _ rhs: T,
        using operation: MuttniksParsers.ComparisonOperator
    ) -> Bool {
        switch operation {
        case .equal: lhs == rhs
        case .notEqual: lhs != rhs
        case .greaterThan: lhs > rhs
        case .greaterThanOrEqual: lhs >= rhs
        case .lessThan: lhs < rhs
        case .lessThanOrEqual: lhs <= rhs
        }
    }

    var numberValue: Double? {
        guard case .number(let text) = value else { return nil }
        return Double(text)
    }

    func replacingChildren(_ children: [JSONNode]) -> JSONNode {
        JSONNode(
            id: id,
            name: name,
            path: path,
            value: value,
            children: children
        )
    }
}
