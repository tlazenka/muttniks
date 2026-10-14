import Foundation

public enum SQLDialect: Sendable, Equatable { case sqlite, postgres }
public enum QuerySQLError: Error, Equatable, Sendable {
    case unsupportedPredicate(QueryPredicate)
}

public struct SQLFragment: Hashable, Sendable {
    public let sql: String
    public let bindings: [QueryValue]
    public init(sql: String, bindings: [QueryValue] = []) {
        self.sql = sql
        self.bindings = bindings
    }
}

public enum QuerySQLInterpreter {
    public static func lower(_ predicate: QueryPredicate, dialect: SQLDialect) throws -> SQLFragment {
        var bindings: [QueryValue] = []

        func placeholder(_ value: QueryValue) -> String {
            bindings.append(value)
            return dialect == .sqlite ? "?" : "$\(bindings.count)"
        }

        func field(_ raw: String) -> String {
            precondition(
                !raw.isEmpty && raw.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" },
                "Invalid query field"
            )
            return "\"\(raw)\""
        }

        func emit(_ p: QueryPredicate) throws -> String {
            switch p {
            case .equals(let f, let v): return "\(field(f)) = \(placeholder(v))"
            case .atLeast(let f, let v): return "\(field(f)) >= \(placeholder(v))"
            case .lessThan(let f, let v): return "\(field(f)) < \(placeholder(v))"
            case .missing: return "1 = 0"
            case .structure: throw QuerySQLError.unsupportedPredicate(p)
            case .contains(let f, let value):
                let op = dialect == .postgres ? "ILIKE" : "LIKE"
                return "\(field(f)) \(op) \(placeholder(.text("%\(value)%")))"
            case .not(let child): return "NOT (\(try emit(child)))"
            case .all(let children):
                return children.isEmpty ? "1 = 1" : try children.map { "(\(try emit($0)))" }.joined(separator: " AND ")
            case .any(let children):
                return children.isEmpty ? "1 = 0" : try children.map { "(\(try emit($0)))" }.joined(separator: " OR ")
            }
        }
        return .init(sql: try emit(predicate), bindings: bindings)
    }
}
