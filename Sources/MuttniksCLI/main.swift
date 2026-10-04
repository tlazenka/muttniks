//
//  main.swift
//  Muttniks
//
//  Created by Francis Lazenka on 10/1/26.
//

import Foundation
import Muttniks

let arguments = Array(CommandLine.arguments.dropFirst())
guard !arguments.isEmpty else {
    exit(EXIT_FAILURE)
}

let expression = arguments.joined(separator: " ")

do {
    let database = try Database(path: ":memory:")
    try database.execute(
        """
        CREATE TABLE earthquake_feed (
            document TEXT NOT NULL CHECK(json_valid(document))
        )
        """
    )

    guard
        let url = Bundle.module.url(
            forResource: "SampleData",
            withExtension: "json"
        )
    else {
        throw CocoaError(.fileNoSuchFile)
    }

    let document = try String(contentsOf: url, encoding: .utf8)
    try database.execute(
        "INSERT INTO earthquake_feed(document) VALUES (\(document))"
    )

    let parsed = try parseQueryExpression(expression)
    let sql = SQL.earthquakeIDs(matching: parsed)
    let ids = try database.query(sql) { row in
        row.string(at: 0)!
    }

    for id in ids {
        print(id)
    }
} catch {
    let message = "Error: \(error.localizedDescription)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(EXIT_FAILURE)
}
