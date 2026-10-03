import PuzzolaParsers
import Testing

@testable import Puzzola

@Test func parsesAndExpression() throws {
    let expression = try QueryParser.parse(
        "$.properties.mag >= 4 && $.geometry.coordinates[2] < 20"
    ).get()

    let expected = Expression.and(
        .comparison(
            Comparison(
                path: "$.properties.mag",
                operation: .greaterThanOrEqual,
                value: .number(4)
            )
        ),
        .comparison(
            Comparison(
                path: "$.geometry.coordinates[2]",
                operation: .lessThan,
                value: .number(20)
            )
        )
    )
    #expect(expression == expected)
}

@Test func andBindsTighterThanOr() throws {
    let expression = try QueryParser.parse(
        "$.properties.mag >= 6 || $.properties.mag >= 4 && $.geometry.coordinates[2] < 20"
    ).get()

    guard case .or(_, let rhs) = expression else {
        Issue.record("Expected root OR")
        return
    }
    guard case .and = rhs else {
        Issue.record("Expected right AND")
        return
    }
}

@Test func compilesExpressionToBoundSQL() throws {
    let expression = try QueryParser.parse(
        "$.properties.mag >= 4 && $.geometry.coordinates[2] < 20"
    ).get()
    let sql = SQL.earthquakeIDs(matching: expression)

    #expect(sql.text.contains(" AND "))
    #expect(
        sql.bindings == [
            .text("$.properties.mag"),
            .real(4),
            .text("$.geometry.coordinates[2]"),
            .real(20),
        ]
    )
}

private func comparison(
    _ path: String,
    _ operation: ComparisonOperator,
    _ value: QueryValue
) -> Expression {
    .comparison(Comparison(path: path, operation: operation, value: value))
}

@Test func parsesEveryComparisonOperator() throws {
    let cases: [(String, ComparisonOperator)] = [
        ("=", .equal), ("!=", .notEqual), (">", .greaterThan),
        (">=", .greaterThanOrEqual), ("<", .lessThan), ("<=", .lessThanOrEqual)
    ]
    for (source, operation) in cases {
        #expect(try QueryParser.parse("$.x \(source) 1").get() == comparison("$.x", operation, .number(1)))
    }
}

@Test func parsesAllSupportedQueryValues() throws {
    #expect(try QueryParser.parse("$.x = 12.5").get() == comparison("$.x", .equal, .number(12.5)))
    #expect(try QueryParser.parse("$.x = -12.5").get() == comparison("$.x", .equal, .number(-12.5)))
    #expect(try QueryParser.parse("$.x = \"hello world\"").get() == comparison("$.x", .equal, .string("hello world")))
    #expect(try QueryParser.parse("$.x = true").get() == comparison("$.x", .equal, .bool(true)))
    #expect(try QueryParser.parse("$.x = false").get() == comparison("$.x", .equal, .bool(false)))
    #expect(try QueryParser.parse("$.x = null").get() == comparison("$.x", .equal, .null))
}

@Test func queryTokensAllowSurroundingWhitespace() throws {
    #expect(try QueryParser.parse("  $.x   =   true  ").get() == comparison("$.x", .equal, .bool(true)))
}

@Test func queryPathTextPreservesOriginalPathSpelling() throws {
    #expect(try QueryParser.parse("$.items[#-2].type = \"Point\"").get() ==
        comparison("$.items[#-2].type", .equal, .string("Point")))
}

@Test func conjunctionAssociatesToTheLeft() throws {
    let parsed = try QueryParser.parse("$.a = 1 && $.b = 2 && $.c = 3").get()
    let a = comparison("$.a", .equal, .number(1))
    let b = comparison("$.b", .equal, .number(2))
    let c = comparison("$.c", .equal, .number(3))
    #expect(parsed == .and(.and(a, b), c))
}

@Test func disjunctionAssociatesToTheLeft() throws {
    let parsed = try QueryParser.parse("$.a = 1 || $.b = 2 || $.c = 3").get()
    let a = comparison("$.a", .equal, .number(1))
    let b = comparison("$.b", .equal, .number(2))
    let c = comparison("$.c", .equal, .number(3))
    #expect(parsed == .or(.or(a, b), c))
}

@Test func andHasHigherPrecedenceThanOrOnBothSides() throws {
    let parsed = try QueryParser.parse("$.a = 1 && $.b = 2 || $.c = 3 && $.d = 4").get()
    #expect(parsed == .or(
        .and(comparison("$.a", .equal, .number(1)), comparison("$.b", .equal, .number(2))),
        .and(comparison("$.c", .equal, .number(3)), comparison("$.d", .equal, .number(4)))
    ))
}

@Test func queryRejectsTrailingJunkAtUnparsedOffset() {
    switch QueryParser.parse("$.x = 1 junk") {
    case .success:
        Issue.record("Expected trailing text to fail")
    case .failure(let error):
        #expect(error.offset == 8)
        #expect(error.expected == "End of expression")
    }
}

@Test func queryRejectsMissingRightComparisonAfterAnd() {
    switch QueryParser.parse("$.x = 1 &&") {
    case .success:
        Issue.record("Expected incomplete conjunction to fail")
    case .failure(let error):
        #expect(error.offset == 10)
    }
}

@Test func queryRejectsMissingRightConjunctionAfterOr() {
    switch QueryParser.parse("$.x = 1 ||") {
    case .success:
        Issue.record("Expected incomplete disjunction to fail")
    case .failure(let error):
        #expect(error.offset == 10)
    }
}

@Test func unterminatedQuotedStringReportsEndOffset() {
    switch QueryParser.parse("$.x = \"abc") {
    case .success:
        Issue.record("Expected unterminated string to fail")
    case .failure(let error):
        #expect(error.offset == 10)
        #expect(error.expected == "'\"'")
    }
}

@Test func numberAllowsLeadingDecimalPointAfterMinusOnlyWhenDigitExists() throws {
    #expect(try QueryParser.parse("$.x = -.5").get() == comparison("$.x", .equal, .number(-0.5)))
}

@Test func numberCurrentlyAcceptsTrailingDecimalPoint() throws {
    #expect(try QueryParser.parse("$.x = 1.").get() == comparison("$.x", .equal, .number(1)))
}

@Test func quotedStringsCurrentlyDoNotInterpretEscapes() {
    switch QueryParser.parse(#"$.x = "a\"b""#) {
    case .success:
        Issue.record("Current parser should stop at escaped quote")
    case .failure(let error):
        #expect(error.expected == "End of expression")
    }
}
