#if canImport(SpriteKit)
import SpriteKit
import WhaleyCore

public enum SpriteKitGameAction {
    public static func interpret(
        _ action: GameAction,
        callback: @escaping (UInt64, SKNode) -> Void = { _, _ in },
        texture: @escaping (String) -> SKTexture = { SKTexture(imageNamed: $0) }
    ) -> SKAction {
        switch action {
        case let .move(to, duration):
            return .move(to: CGPoint(x: to.x, y: to.y), duration: seconds(duration))
        case let .scale(to, duration):
            return .scale(to: to, duration: seconds(duration))
        case let .rotate(degrees, duration):
            return .rotate(byAngle: -degrees * .pi / 180, duration: seconds(duration))
        case let .wait(duration):
            return .wait(forDuration: seconds(duration))
        case let .fade(opacity, duration):
            return .fadeAlpha(to: opacity, duration: seconds(duration))
        case let .animate(frameNames, frameDuration):
            return .animate(with: frameNames.map(texture), timePerFrame: seconds(frameDuration))
        case let .sequence(actions):
            return .sequence(actions.map { interpret($0, callback: callback, texture: texture) })
        case let .repeatForever(action):
            return .repeatForever(interpret(action, callback: callback, texture: texture))
        case let .callback(id):
            return .customAction(withDuration: 0) { node, _ in
                callback(id, node)
            }
        }
    }

    private static func seconds(_ duration: GameDuration) -> TimeInterval {
        Double(duration.microseconds) / 1_000_000
    }
}
#endif
