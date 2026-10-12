import CSQLite
import Foundation
import SemanticCore

public struct SceneGameTime: Hashable, Comparable, Sendable, Codable {
    public let microseconds: Int64
    public init(microseconds: Int64) { self.microseconds = max(0, microseconds) }
    public static func seconds(_ value: Double) -> Self {
        .init(microseconds: Int64((max(0, value) * 1_000_000).rounded()))
    }
    public var seconds: Double { Double(microseconds) / 1_000_000 }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.microseconds < rhs.microseconds }
    public var clockText: String {
        let centiseconds = microseconds / 10_000
        let minutes = centiseconds / 6_000
        let seconds = (centiseconds / 100) % 60
        let hundredths = centiseconds % 100
        return String(format: "%02lld:%02lld.%02lld", minutes, seconds, hundredths)
    }
}

public struct SceneTimeScrubSession: Hashable, Sendable {
    public let liveTime: SceneGameTime
    public let step: SceneGameTime
    public internal(set) var previewTime: SceneGameTime

    public init(liveTime: SceneGameTime, step: SceneGameTime = .seconds(0.25)) {
        precondition(step.microseconds > 0)
        self.liveTime = liveTime
        self.step = step
        self.previewTime = liveTime
    }

    public mutating func step(by steps: Int) {
        let delta = Int64(steps) * step.microseconds
        previewTime = .init(microseconds: max(0, previewTime.microseconds + delta))
    }

    public mutating func update(horizontal: Double, pointsPerStep: Double = 32) {
        let steps = SemanticScrubInterpreter(pointsPerStep: pointsPerStep).steps(for: horizontal)
        let delta = Int64(steps) * step.microseconds
        previewTime = .init(microseconds: max(0, liveTime.microseconds + delta))
    }
}

public enum SceneObjectScrubCategory: Int, CaseIterable, Sendable, Codable {
    case position
    case size
    case image

    public var title: String {
        switch self {
        case .position: "Position"
        case .size: "Size"
        case .image: "Image"
        }
    }
}

public struct SceneObjectScrubSession: Hashable, Sendable {
    public let pointsPerStep: Double
    public internal(set) var category: SceneObjectScrubCategory = .position
    public internal(set) var scalarSteps: Int = 0

    public init(pointsPerStep: Double = 32) { self.pointsPerStep = pointsPerStep }

    public mutating func stepScalar(by delta: Int) { scalarSteps += delta }

    public mutating func stepCategory(by delta: Int) {
        let cases = SceneObjectScrubCategory.allCases
        category = cases[min(max(category.rawValue + delta, 0), cases.count - 1)]
    }

    public mutating func update(horizontal: Double, vertical: Double) {
        let scrub = SemanticScrubInterpreter(pointsPerStep: pointsPerStep)
        let index = scrub.selectionIndex(
            translation: vertical,
            count: SceneObjectScrubCategory.allCases.count
        )
        category = SceneObjectScrubCategory.allCases[index]
        scalarSteps = scrub.steps(for: horizontal)
    }
}
