import Foundation
import QueryBlaster

public struct FeedRecord: Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable { case earthquake, photograph }
    public let id: String
    public let kind: Kind
    public let fields: [String: QueryValue]
    public let imageURL: URL?

    public init(id: String, kind: Kind, fields: [String: QueryValue], imageURL: URL? = nil) {
        self.id = id
        self.kind = kind
        self.fields = fields
        self.imageURL = imageURL
    }

    public subscript(_ field: String) -> QueryValue? { fields[field] }
}

public enum FeedField {
    public static let type = "type"
    public static let city = "city"
    public static let country = "country"
    public static let place = "place"
    public static let timestamp = "timestamp"
    public static let magnitude = "magnitude"
    public static let photographer = "photographer"
    public static let title = "title"
}
