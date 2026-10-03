//
//  ISO8601DateFormatter+Extension.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import Foundation

extension ISO8601DateFormatter {
    nonisolated static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension JSONEncoder.DateEncodingStrategy {
    static let iso8601WithFractionalSeconds = custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(ISO8601DateFormatter.withFractionalSeconds.string(from: date))
    }
}

extension JSONDecoder.DateDecodingStrategy {
    static let iso8601WithFractionalSeconds = custom { decoder in
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        guard
            let date = ISO8601DateFormatter.withFractionalSeconds.date(from: stringValue)
        else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Error decoding date string: \(stringValue)"
            )
        }
        return date
    }
}

extension JSONEncoder {
    static let doorJsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601WithFractionalSeconds
        return encoder
    }()
}

extension JSONDecoder {
    static let doorJsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
        return decoder
    }()
}
