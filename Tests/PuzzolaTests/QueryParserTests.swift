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
