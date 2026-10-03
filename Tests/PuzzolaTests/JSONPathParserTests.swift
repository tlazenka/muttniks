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

@Test func parsesRootJSONPath() throws {
    #expect(try JSONPathParser.parse("$").get().components.isEmpty)
}

@Test func parsesAllSupportedJSONPathComponentKinds() throws {
    let parsed = try JSONPathParser.parse("$.items[2][#-1][#]._value9").get()
    #expect(parsed.components == [
        .member("items"),
        .index(2),
        .fromEnd(1),
        .append,
        .member("_value9")
    ])
}

@Test func JSONPathMemberAllowsNumbersAfterDot() throws {
    let parsed = try JSONPathParser.parse("$.123").get()
    #expect(parsed.components == [.member("123")])
}

@Test func JSONPathRejectsEmptyMemberAtComponentOffset() {
    switch JSONPathParser.parse("$..mag") {
    case .success:
        Issue.record("Expected malformed member to fail")
    case .failure(let error):
        #expect(error.offset == 1)
        #expect(error.expected == "JSONPath component")
    }
}

@Test func JSONPathRejectsTrailingTextAtFirstUnparsedOffset() {
    switch JSONPathParser.parse("$.mag trailing") {
    case .success:
        Issue.record("Expected trailing input to fail")
    case .failure(let error):
        #expect(error.offset == 5)
        #expect(error.expected == "JSONPath component")
    }
}

@Test func JSONPathMalformedIndexIsObservedAsTrailinFailure() {
    switch JSONPathParser.parse("$.items[x]") {
    case .success:
        Issue.record("Expected malformed index to fail")
    case .failure(let error):
        #expect(error.offset == 7)
        #expect(error.expected == "JSONPath component")
    }
}

@Test func JSONPathRequiresDollarRoot() {
    switch JSONPathParser.parse(".properties.mag") {
    case .success:
        Issue.record("Expected to fail with no root")
    case .failure(let error):
        #expect(error == ParseError(offset: 0, expected: "'$'"))
    }
}
