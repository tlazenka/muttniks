import PuzzolaParsers
import Testing

@testable import Puzzola

@Test func parsesJSONPathComponents() throws {
    let parsed = try JSONPathParser.parse("$.properties.items[2]").get()
    #expect(
        parsed.components == [
            .member("properties"),
            .member("items"),
            .index(2),
        ]
    )
}

@Test func rejectsMalformedJSONPath() {
    switch JSONPathParser.parse("properties..mag") {
    case .success:
        Issue.record("Expected malformed JSONPath to fail")
    case .failure(let error):
        #expect(error.offset == 0)
    }
}

@Test func jsonPathInterpolationUsesBinding() {
    let path = JSONPath(validated: "$.properties.mag")
    let sql: SQL = "SELECT json_extract(document, \(jsonPath: path))"

    #expect(sql.text == "SELECT json_extract(document, ?)")
    #expect(sql.bindings == [.text("$.properties.mag")])
}
