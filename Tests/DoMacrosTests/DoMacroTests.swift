import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import XCTest

@testable import DoMacros

final class DoMacroTests: XCTestCase {
    private func expand(_ source: String) -> String {
        Parser.parse(source: source)
            .expand(
                macros: ["Do": DoMacro.self],
                contextGenerator: { _ in BasicMacroExpansionContext() }
            )
            .description
    }

    func testDependentBindingsBecomeNestedResultSwitchesAndFinalExpressionIsLifted() {
        let expanded = expand(
            """
            @Do
            func getUser() -> Result<User, ApiError> {
                let user = #bind(getUser())
                let knocks = #bind(getKnocks(for: user))
                Feed(user: user, knocks: knocks)
            }
            """
        )

        XCTAssertFalse(expanded.contains("#bind"))
        XCTAssertTrue(expanded.contains("switch getUser()"))
        XCTAssertTrue(expanded.contains("case .success(let user)"))
        XCTAssertTrue(expanded.contains("switch getKnocks(for: user)"))
        XCTAssertTrue(expanded.contains("case .success(let knocks)"))
        XCTAssertTrue(expanded.contains("return .success(Feed(user: user, knocks: knocks))"))
        XCTAssertTrue(expanded.contains("return .failure(error)"))
    }

}
