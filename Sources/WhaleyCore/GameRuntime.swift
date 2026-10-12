public struct GamePoint: Sendable, Hashable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct GameSize: Sendable, Hashable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct GameEntityID: Sendable, Hashable, RawRepresentable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
}

public struct GameDuration: Sendable, Hashable, Comparable {
    public let microseconds: Int64
    public init(microseconds: Int64) { self.microseconds = microseconds }
    public static func seconds(_ value: Double) -> Self {
        .init(microseconds: Int64((value * 1_000_000).rounded()))
    }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.microseconds < rhs.microseconds }
}

public enum GameAction: Sendable, Hashable {
    case move(to: GamePoint, duration: GameDuration)
    case scale(to: Double, duration: GameDuration)
    case rotate(byDegrees: Double, duration: GameDuration)
    case wait(GameDuration)
    case fade(toOpacity: Double, duration: GameDuration)
    case animate(frameNames: [String], frameDuration: GameDuration)
    indirect case sequence([GameAction])
    indirect case repeatForever(GameAction)
    case callback(UInt64)
}

public struct GameScheduleID: Sendable, Hashable, RawRepresentable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
}

public struct GameScheduledCallback: Sendable, Hashable {
    public let id: GameScheduleID
    public let callback: UInt64
    public let interval: GameDuration
    public var nextFire: GameDuration
}

public struct GameScheduler: Sendable {
    public private(set) var elapsed = GameDuration(microseconds: 0)
    private var nextID: UInt64 = 1
    private var entries: [GameScheduleID: GameScheduledCallback] = [:]

    public init() {}

    public mutating func schedule(callback: UInt64, every interval: GameDuration) -> GameScheduleID {
        precondition(interval.microseconds > 0)
        let id = GameScheduleID(rawValue: nextID)
        nextID += 1
        entries[id] = .init(
            id: id,
            callback: callback,
            interval: interval,
            nextFire: .init(microseconds: elapsed.microseconds + interval.microseconds)
        )
        return id
    }

    public mutating func cancel(_ id: GameScheduleID) { entries[id] = nil }

    public mutating func advance(by duration: GameDuration) -> [UInt64] {
        precondition(duration.microseconds >= 0)
        elapsed = .init(microseconds: elapsed.microseconds + duration.microseconds)
        var due: [(Int64, UInt64, GameScheduleID)] = []
        for (id, entry) in entries {
            var fire = entry.nextFire.microseconds
            while fire <= elapsed.microseconds {
                due.append((fire, entry.callback, id))
                fire += entry.interval.microseconds
            }
            if fire != entry.nextFire.microseconds {
                var updated = entry
                updated.nextFire = .init(microseconds: fire)
                entries[id] = updated
            }
        }
        due.sort { $0.0 == $1.0 ? $0.2.rawValue < $1.2.rawValue : $0.0 < $1.0 }
        return due.map { $0.1 }
    }
}

public struct GameNode: Sendable, Hashable {
    public let id: GameEntityID
    public var position: GamePoint
    public var size: GameSize
    public var scaleX: Double
    public var scaleY: Double
    public var rotationDegrees: Double
    public var zIndex: Int

    public init(
        id: GameEntityID,
        position: GamePoint = .init(x: 0, y: 0),
        size: GameSize = .init(width: 0, height: 0),
        scaleX: Double = 1,
        scaleY: Double = 1,
        rotationDegrees: Double = 0,
        zIndex: Int = 0
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotationDegrees = rotationDegrees
        self.zIndex = zIndex
    }
}

public struct TileCoordinate: Sendable, Hashable {
    public let column: Int
    public let row: Int
    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}

public struct TileLayer: Sendable, Hashable {
    public let width: Int
    public let height: Int
    private var gids: [UInt32]

    public init(width: Int, height: Int, gids: [UInt32]) {
        precondition(width >= 0 && height >= 0)
        precondition(gids.count == width * height)
        self.width = width
        self.height = height
        self.gids = gids
    }

    public func gid(at coordinate: TileCoordinate) -> UInt32 {
        guard coordinate.column >= 0, coordinate.column < width,
            coordinate.row >= 0, coordinate.row < height
        else { return 0 }
        return gids[coordinate.row * width + coordinate.column]
    }

    public mutating func setGID(_ gid: UInt32, at coordinate: TileCoordinate) {
        guard coordinate.column >= 0, coordinate.column < width,
            coordinate.row >= 0, coordinate.row < height
        else { return }
        gids[coordinate.row * width + coordinate.column] = gid
    }
}

public struct TileMap: Sendable, Hashable {
    public let size: GameSize
    public let tileSize: GameSize
    public var layers: [String: TileLayer]
    public init(size: GameSize, tileSize: GameSize, layers: [String: TileLayer]) {
        self.size = size
        self.tileSize = tileSize
        self.layers = layers
    }
    public func gid(in layer: String, at coordinate: TileCoordinate) -> UInt32 {
        layers[layer]?.gid(at: coordinate) ?? 0
    }
}

public enum GameInput: Sendable, Hashable {
    case began(id: UInt64, at: GamePoint)
    case moved(id: UInt64, to: GamePoint)
    case ended(id: UInt64, at: GamePoint)
}

public enum GameEvent: Sendable, Hashable {
    case actionStarted(entity: GameEntityID, action: GameAction)
    case input(GameInput)
}

public struct GameScene: Sendable {
    public private(set) var elapsed: GameDuration = .init(microseconds: 0)
    public private(set) var nodes: [GameEntityID: GameNode] = [:]
    public private(set) var events: [GameEvent] = []
    public var tileMap: TileMap?

    public init(tileMap: TileMap? = nil) { self.tileMap = tileMap }
    public mutating func insert(_ node: GameNode) { nodes[node.id] = node }
    public mutating func record(_ input: GameInput) { events.append(.input(input)) }
    public mutating func run(_ action: GameAction, on entity: GameEntityID) {
        precondition(nodes[entity] != nil)
        events.append(.actionStarted(entity: entity, action: action))
    }
    public mutating func advance(by duration: GameDuration) {
        precondition(duration.microseconds >= 0)
        elapsed = .init(microseconds: elapsed.microseconds + duration.microseconds)
    }
}
