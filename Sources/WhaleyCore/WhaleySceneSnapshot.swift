import Foundation

public struct WhaleySceneSnapshot: Codable, Sendable, Equatable {
    public struct Cell: Codable, Sendable, Hashable {
        public let x: Int
        public let y: Int
        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }
    public enum Kind: String, Codable, Sendable { case wall, ground, bubble, coin, flame, goal }
    public struct Element: Codable, Sendable, Equatable {
        public let kind: Kind
        public let x: Int
        public let y: Int
        public init(kind: Kind, x: Int, y: Int) {
            self.kind = kind
            self.x = x
            self.y = y
        }
    }
    public let sequence: Int
    public let session: String
    public let level: Int
    public let gameTime: Double
    public let dead: Bool
    public let player: Cell
    public let elements: [Element]
    public init(
        sequence: Int,
        session: String,
        level: Int,
        gameTime: Double,
        dead: Bool,
        player: Cell,
        elements: [Element]
    ) {
        self.sequence = sequence
        self.session = session
        self.level = level
        self.gameTime = gameTime
        self.dead = dead
        self.player = player
        self.elements = elements
    }
}

public enum WhaleyTerminalRenderer {
    public static func lines(_ snapshot: WhaleySceneSnapshot, size: Int) -> [String] {
        let size = max(1, size | 1)
        let half = size / 2
        let left = snapshot.player.x - half
        let bottom = snapshot.player.y - half
        var pixels: [WhaleySceneSnapshot.Cell: Character] = [:]
        for kind in [WhaleySceneSnapshot.Kind.wall, .ground, .coin, .goal, .bubble, .flame] {
            for element in snapshot.elements where element.kind == kind {
                let cell = WhaleySceneSnapshot.Cell(x: element.x, y: element.y)
                pixels[cell] =
                    switch kind {
                    case .wall: "#"
                    case .ground: "="
                    case .coin: "$"
                    case .goal: "O"
                    case .bubble: "o"
                    case .flame: "^"
                    }
            }
        }
        pixels[snapshot.player] = "W"
        var result = ["+" + String(repeating: "-", count: size) + "+"]
        for row in (0..<size).reversed() {
            let characters = (0..<size)
                .map { column in
                    pixels[.init(x: left + column, y: bottom + row)] ?? "·"
                }
            result.append("|" + String(characters) + "|")
        }
        result.append("+" + String(repeating: "-", count: size) + "+")
        return result
    }
}
