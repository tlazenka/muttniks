import Foundation

public struct WhaleyRecordedRun: Codable, Identifiable, Sendable {
    public let id: UUID
    public let level: Int
    public let startedAt: Date
    public var endedAt: Date?
    public var samples: [WhaleyRunSample]
    public var inputs: [WhaleyRawInput]
    public var assistance: [Int]?
    public var gameplayEvents: [WhaleyGameplayEvent]

    public init(
        id: UUID,
        level: Int,
        startedAt: Date,
        endedAt: Date?,
        samples: [WhaleyRunSample],
        inputs: [WhaleyRawInput],
        assistance: [Int]? = nil,
        gameplayEvents: [WhaleyGameplayEvent] = []
    ) {
        self.id = id
        self.level = level
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.samples = samples
        self.inputs = inputs
        self.assistance = assistance
        self.gameplayEvents = gameplayEvents
    }
}

public struct WhaleyGameplayEvent: Codable, Sendable, Equatable {
    public enum Action: String, Codable, Sendable {
        case bubbleCreated, bubbleExpanded, bubbleCollision, bubbleBounce, coinCollected, levelCompleted
    }
    public let time: TimeInterval
    public let action: Action
    public let x: Double
    public let y: Double
    public let objectID: String?
    public init(time: TimeInterval, action: Action, x: Double, y: Double, objectID: String? = nil) {
        self.time = time
        self.action = action
        self.x = x
        self.y = y
        self.objectID = objectID
    }
}

public struct WhaleyRunSample: Codable, Sendable, Equatable {
    public let time: TimeInterval
    public let x: Double
    public let y: Double
    public let dead: Bool
    public init(time: TimeInterval, x: Double, y: Double, dead: Bool) {
        self.time = time
        self.x = x
        self.y = y
        self.dead = dead
    }
}

public struct WhaleyRawInput: Codable, Sendable, Equatable {
    public enum Phase: String, Codable, Sendable { case began, moved, ended, cancelled }
    public let time: TimeInterval
    public let phase: Phase
    public let x: Double
    public let y: Double
    public init(time: TimeInterval, phase: Phase, x: Double, y: Double) {
        self.time = time
        self.phase = phase
        self.x = x
        self.y = y
    }
}
