import XCTest

@testable import WhaleyCore

final class WhaleySceneSnapshotTests: XCTestCase {
    func testRoundTripAndTerminalProjection() throws {
        let snapshot = WhaleySceneSnapshot(
            sequence: 32,
            session: "abc",
            level: 2,
            gameTime: 1.5,
            dead: false,
            player: .init(x: 5, y: 5),
            elements: [
                .init(kind: .wall, x: 4, y: 5),
                .init(kind: .coin, x: 6, y: 5),
                .init(kind: .bubble, x: 5, y: 6),
            ]
        )
        let decoded = try JSONDecoder()
            .decode(
                WhaleySceneSnapshot.self,
                from: JSONEncoder().encode(snapshot)
            )
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(
            WhaleyTerminalRenderer.lines(decoded, size: 3),
            ["+---+", "|·o·|", "|#W$|", "|···|", "+---+"]
        )
    }

    func testPlayerTakesPriorityOverOtherElements() {
        let snapshot = WhaleySceneSnapshot(
            sequence: 1,
            session: "s",
            level: 1,
            gameTime: 0,
            dead: false,
            player: .init(x: 0, y: 0),
            elements: [.init(kind: .flame, x: 0, y: 0)]
        )
        XCTAssertEqual(
            WhaleyTerminalRenderer.lines(snapshot, size: 1),
            ["+-+", "|W|", "+-+"]
        )
    }
}
