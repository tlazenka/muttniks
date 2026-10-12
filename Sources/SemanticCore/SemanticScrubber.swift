import Foundation

public struct SemanticScrubInterpreter: Hashable, Sendable {
    public var pointsPerStep: Double
    public init(pointsPerStep: Double = 32) { self.pointsPerStep = pointsPerStep }

    public func steps(for translation: Double) -> Int {
        Int((translation / pointsPerStep).rounded())
    }

    public func selectionIndex(translation: Double, count: Int, origin: Int = 0) -> Int {
        precondition(count > 0)
        return min(count - 1, max(0, origin + steps(for: translation)))
    }
}
