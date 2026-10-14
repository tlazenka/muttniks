import CoreGraphics
import Foundation
import WhaleyCore

@MainActor
final class WhaleyRunRecorder {
    static let shared = WhaleyRunRecorder()

    var completed: [WhaleyRecordedRun] = []
    var history: SQLiteRunHistory?
    var current: WhaleyRecordedRun?
    var lastSampleTime: TimeInterval = -.infinity
    var lastLevel: Int?
    enum RecordingLifecycle {
        case idle
        case recording
        case finished
    }
    var lifecycle: RecordingLifecycle = .idle
    var appliedAssistance: [Int] = []

    init() { load() }

    var runCount: Int { completed.count + (current == nil ? 0 : 1) }
    var recordedRuns: [WhaleyRecordedRun] { completed + (current.map { [$0] } ?? []) }

    func recentRuns(level: Int, limit: Int = 12) -> [WhaleyRecordedRun] {
        let stored: [WhaleyRecordedRun]
        if let history, let payloads = try? history.payloads(level: level, limit: limit) {
            stored = Array(
                payloads.compactMap { try? JSONDecoder.whaleyRunDecoder.decode(WhaleyRecordedRun.self, from: $0) }
                    .reversed()
            )
        } else {
            stored = Array(completed.filter { $0.level == level }.suffix(limit))
        }
        let active: [WhaleyRecordedRun]
        if let current, current.level == level {
            active = [current]
        } else {
            active = []
        }
        return Array((stored + active).suffix(limit))
    }

    func flameSuppressionAssessments(level: Int, positions: [CGPoint]) -> [FlameSuppressionAssessment] {
        guard let history else { return [] }
        let activeJSON = current.flatMap { $0.level == level ? try? JSONEncoder().encode($0) : nil }
        return
            (try? history.flameSuppressionAssessments(
                level: level,
                flamePositions: positions.map { (x: Double($0.x), y: Double($0.y)) },
                activeRunJSON: activeJSON
            )) ?? []
    }

    func insights(level: Int, positions: [CGPoint], query: WhaleyInsightQuery) async -> [WhaleyInsightSummary] {
        guard let history else { return [] }
        let activeJSON = current.flatMap { $0.level == level ? try? JSONEncoder().encode($0) : nil }
        let interpreter = WhaleySQLiteInsightsInterpreter(
            history: history,
            level: level,
            flames: positions.map { (x: Double($0.x), y: Double($0.y)) },
            activeRunJSON: activeJSON
        )
        return (try? await interpreter.execute(query)) ?? []
    }

    func setAppliedAssistance(_ indices: [Int]) { appliedAssistance = indices.sorted() }

    func sample(level: Int, time: TimeInterval, position: CGPoint, dead: Bool) {
        if lastLevel != level {
            finishCurrent()
            lifecycle = .idle
            lastLevel = level
        }
        switch lifecycle {
        case .finished where dead:
            return
        case .idle, .finished:
            guard !dead else { return }
            current = WhaleyRecordedRun(
                id: UUID(),
                level: level,
                startedAt: .now,
                endedAt: nil,
                samples: [],
                inputs: [],
                assistance: appliedAssistance
            )
            lastSampleTime = -.infinity
            lifecycle = .recording
        case .recording:
            break
        }
        if dead {
            lastSampleTime = time
            current?.samples.append(.init(time: time, x: position.x, y: position.y, dead: true))
            finishCurrent()
            lifecycle = .finished
            return
        }
        guard time - lastSampleTime >= 0.1 else { return }
        lastSampleTime = time
        current?.samples.append(.init(time: time, x: position.x, y: position.y, dead: false))
    }

    func gameplay(
        _ action: WhaleyGameplayEvent.Action,
        time: TimeInterval,
        position: CGPoint,
        objectID: String? = nil
    ) {
        guard current != nil, time.isFinite else { return }
        current?.gameplayEvents
            .append(
                .init(
                    time: time,
                    action: action,
                    x: Double(position.x),
                    y: Double(position.y),
                    objectID: objectID
                )
            )
    }

    func input(_ phase: WhaleyRawInput.Phase, time: TimeInterval, point: CGPoint) {
        guard current != nil else { return }
        current?.inputs.append(.init(time: time, phase: phase, x: point.x, y: point.y))
    }

    func finishCurrent() {
        guard var run = current else { return }
        run.endedAt = .now
        completed.append(run)
        current = nil
        if let history {
            do {
                let data = try JSONEncoder.whaleyRunEncoder.encode(run)
                try history.save(id: run.id, level: run.level, endedAt: run.endedAt ?? .now, payload: data)
            } catch {
                assertionFailure(error.localizedDescription)
            }
        } else {
            print("No history available")
        }
    }

    func load() {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else {
            assertionFailure("applicationSupportDirectory unavailable")
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let store = try SQLiteRunHistory(path: directory.appendingPathComponent("whaley-runs.sqlite3").path)
            let payloads = try store.payloads()
            completed = Array(
                payloads.compactMap { try? JSONDecoder.whaleyRunDecoder.decode(WhaleyRecordedRun.self, from: $0) }
                    .reversed()
            )
            history = store
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }
}

extension JSONEncoder {
    static var whaleyRunEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
extension JSONDecoder {
    static var whaleyRunDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
