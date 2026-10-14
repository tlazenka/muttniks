import SpriteKit
import SwiftUI
import UIKit
import WhaleyCore
import WhaleyObjectiveC

struct WhaleyDesignerPoint: Codable, Identifiable {
    let id: String
    let title: String
    let x: Double  // [0, 1]
    let y: Double
    let deaths: Int
    let observations: [WhaleyDesignerAction]
}

struct WhaleyDesignerAction: Codable, Identifiable {
    let action: BubbleAction
    let successes: Int
    let failures: Int
    var id: String { action.rawValue }
    var total: Int { successes + failures }
    var rate: Double { total == 0 ? 0 : Double(successes) / Double(total) }
}

enum BubbleAction: String, CaseIterable, Codable, Identifiable {
    case shootLeft, shootRight, shootBelow
    var id: String { rawValue }
    var title: String {
        switch self {
        case .shootLeft: "Shoot bubble left"
        case .shootRight: "Shoot bubble right"
        case .shootBelow: "Shoot bubble below"
        }
    }
}

@MainActor @Observable
final class WhaleyDesignerStore {
    var points: [WhaleyDesignerPoint] = []
    var lastUpdated: Date?
    var message = ""

    func refresh() {
        let runs = WhaleyRunRecorder.shared.recordedRuns
        let size = WhaleySrcAdventureLevelSize()
        guard size.width > 0, size.height > 0 else {
            points = []
            message = "\(runs.count) recorded run(s) -- waiting for level to load"
            return
        }
        struct Cluster {
            var x: Double
            var y: Double
            var count: Int
        }
        var clusters: [Cluster] = []
        for run in runs {
            guard let deathIndex = run.samples.lastIndex(where: { $0.dead }) else { continue }
            let death = run.samples[deathIndex]
            let targetTime = death.time - 0.8
            let prefix = run.samples.prefix(upTo: deathIndex)
            let choice = prefix.last(where: { $0.time <= targetTime }) ?? prefix.last ?? death
            let x = choice.x / Double(size.width)
            let y = 1 - choice.y / Double(size.height)
            guard x.isFinite, y.isFinite else { continue }
            if let i = clusters.indices.first(where: {
                hypot(clusters[$0].x - x, clusters[$0].y - y) < 0.065
            }) {
                let n = Double(clusters[i].count)
                clusters[i].x = (clusters[i].x * n + x) / (n + 1)
                clusters[i].y = (clusters[i].y * n + y) / (n + 1)
                clusters[i].count += 1
            } else {
                clusters.append(Cluster(x: x, y: y, count: 1))
            }
        }
        points = clusters.enumerated()
            .map { index, cluster in
                WhaleyDesignerPoint(
                    id: "observed-death-\(index)",
                    title: "Observed death point \(index + 1)",
                    x: cluster.x,
                    y: cluster.y,
                    deaths: cluster.count,
                    observations: []
                )
            }
        lastUpdated = .now
        message = "\(runs.count) recorded run(s) -- \(clusters.count) observed death cluster(s)"
    }

}

struct WhaleyHostView: View {
    @State private var designer = WhaleyDesignerStore()
    @State private var designerEnabled = false
    @State private var flameSuppressionAssessments: [FlameSuppressionAssessment] = []
    @State private var flameInsights: [WhaleyInsightSummary] = []
    @State private var showingDifficultyInfo = false
    @State private var selectedPoint: WhaleyDesignerPoint?
    @State private var decisionPoint: WhaleyDesignerPoint?
    @State private var sceneGeneration = 0
    @State private var projectedPoints: [String: CGPoint] = [:]
    @State private var monitor: Task<Void, Never>?

    var body: some View {
        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                SrcWhaleyView { _, view in
                    projectDesignerPoints(in: view)
                }
                .id(sceneGeneration)
                .ignoresSafeArea()

                if designerEnabled {
                    ForEach(designer.points) { point in
                        if let anchor = projectedPoints[point.id], geometry.frame(in: .local).contains(anchor) {
                            WhaleyDesignerCallout(
                                point: point,
                                anchor: anchor,
                                onDecision: { simulateDecision(point) },
                                onInfo: { selectedPoint = point }
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            designerEnabled.toggle()
                            if designerEnabled { designer.refresh() }
                            updateFlameDifficulty()
                        } label: {
                            Label("Designer", systemImage: "fossil.shell")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            showingDifficultyInfo = true
                            Task { await refreshInsights() }
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Difficulty info")

                    }
                    .font(.caption)
                    .padding(6)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))

                    if designerEnabled && designer.points.isEmpty {
                        Text(designer.message)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.leading, 12)
            }
        }
        .onAppear {
            designer.refresh()
            updateFlameDifficulty()
        }
        .sheet(isPresented: $showingDifficultyInfo) {
            NavigationStack {
                Form {
                    Section("Flames, Old and New") {
                        ForEach(flameInsights, id: \.title) { insight in
                            LabeledContent(insight.title, value: insight.detail)
                        }
                    }
                    Section {
                        Text("\(flameSuppressionAssessments.filter(\.isSuppressed).count) suppressed flame(s)")
                            .font(.footnote)
                        ForEach(flameSuppressionAssessments) { assessment in
                            LabeledContent(
                                "Flame \(assessment.index + 1)",
                                value:
                                    "\(assessment.nearbyDeaths) nearby deaths (\(assessment.isSuppressed ? "Suppressed" : "Active"))"
                            )
                        }
                    }
                    header: {
                        Text("Flame Assistance")
                    } footer: {
                        Text("We suppress flames after repeated deaths nearby")
                    }
                }
                .navigationTitle("Difficulty")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { showingDifficultyInfo = false } }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if designerEnabled { designer.refresh() }
                updateFlameDifficulty()
            }
        }
        .sheet(item: $selectedPoint) { point in
            WhaleyStatisticsSheet(point: point)
        }
        .sheet(item: $decisionPoint) { point in
            WhaleyChoiceSheet(point: point) { action in
                beginDemoAction(action, at: point)
            }
        }
    }

    @MainActor private func refreshInsights() async {
        let positions = WhaleySrcFlamePositions().map { $0.cgPointValue }
        guard let level = WhaleyRunRecorder.shared.recordedRuns.last?.level else { return }
        flameInsights = await WhaleyRunRecorder.shared.insights(
            level: level,
            positions: positions,
            query: .flameRanking
        )
    }

    private func updateFlameDifficulty() {
        let positions = WhaleySrcFlamePositions().map { $0.cgPointValue }
        guard !positions.isEmpty else { return }
        guard let level = WhaleyRunRecorder.shared.recordedRuns.last?.level else { return }
        let assessments = WhaleyRunRecorder.shared.flameSuppressionAssessments(level: level, positions: positions)
        let previous = flameSuppressionAssessments.filter(\.isSuppressed).map(\.index)
        let suppressed = assessments.filter(\.isSuppressed).map(\.index)
        if assessments != flameSuppressionAssessments { flameSuppressionAssessments = assessments }
        WhaleyRunRecorder.shared.setAppliedAssistance(suppressed)
        if suppressed != previous {
            WhaleySrcSetSuppressedFlames(suppressed.map { NSNumber(value: $0) })
        }
    }

    private func simulateDecision(_ point: WhaleyDesignerPoint) {
        guard WhaleySrcAdventurePrepareCheckpoint(CGPoint(x: point.x, y: point.y)) else { return }
        decisionPoint = point
    }

    private func beginDemoAction(_ action: BubbleAction, at point: WhaleyDesignerPoint) {
        decisionPoint = nil
        guard let engineAction = action.engineDemoAction else { return }
        guard WhaleySrcAdventurePerformAction(engineAction) else { return }

        monitor?.cancel()
        monitor = Task { @MainActor in
            while !Task.isCancelled {
                if WhaleySrcAdventurePlayerIsDead() { return }
                if let next = nextPoint(after: point), hasReached(next) {
                    decisionPoint = next
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func nextPoint(after point: WhaleyDesignerPoint) -> WhaleyDesignerPoint? {
        designer.points.filter { $0.x > point.x }.min { $0.x < $1.x }
    }

    private func hasReached(_ point: WhaleyDesignerPoint) -> Bool {
        WhaleySrcPlayerPosition().x >= CGFloat(point.x) * 320.0
    }

    private func projectDesignerPoints(in view: SrcWhaleySKView) {
        guard designerEnabled else { return }
        var next: [String: CGPoint] = [:]
        for point in designer.points {
            let projected = WhaleySrcAdventureViewPoint(CGPoint(x: point.x, y: point.y))
            if projected.x.isFinite && projected.y.isFinite { next[point.id] = projected }
        }
        if next != projectedPoints { projectedPoints = next }
    }
}

private struct WhaleyDesignerCallout: View {
    let point: WhaleyDesignerPoint
    let anchor: CGPoint
    let onDecision: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onDecision) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(point.title).font(.caption.bold())
                    Text("\(point.deaths) death(s) -- tap to make your choice")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button(action: onInfo) {
                Image(systemName: "info.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Full stats")
        }
        .padding(8)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 9))
        .position(x: anchor.x + 74, y: anchor.y - 48)
        .accessibilityElement(children: .contain)
    }
}

private struct WhaleyStatisticsSheet: View {
    let point: WhaleyDesignerPoint
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Checkpoint") {
                    Text(point.title)
                    LabeledContent("Recorded deaths", value: "\(point.deaths)")
                }
                Section("Observed Actions") {
                    if point.observations.isEmpty {
                        Text("Not yet classified").foregroundStyle(.secondary)
                    }
                    ForEach(point.observations.sorted { $0.rate > $1.rate }) { item in
                        VStack(alignment: .leading) {
                            Text(item.action.title)
                            Text(
                                "\(item.successes) successes, \(item.failures) failures (\(Int(item.rate * 100))%)"
                            )
                            .font(.caption).foregroundStyle(.secondary)
                            ProgressView(value: item.rate)
                        }
                    }
                }
            }
            .navigationTitle("Death Stats")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct WhaleyChoiceSheet: View {
    let point: WhaleyDesignerPoint
    let onSelect: (BubbleAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: BubbleAction?
    private var ranked: [WhaleyDesignerAction] {
        point.observations.filter { $0.total >= 5 }.sorted { $0.rate > $1.rate }
    }
    var body: some View {
        NavigationStack {
            List {
                Text(point.title).font(.title2.bold())
                Text("Choose an option, ranked by history")
                if ranked.count >= 2, let best = ranked.first, let worst = ranked.last, best.id != worst.id {
                    ForEach([best, worst]) { item in
                        Button(item.action.title) {
                            selected = item.action
                            onSelect(item.action)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Text("Not enough rankings yet. These are ordered by defaults")
                        .foregroundStyle(.secondary)
                    ForEach([BubbleAction.shootLeft, .shootRight, .shootBelow]) { action in
                        Button(action.title) {
                            selected = action
                            onSelect(action)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Single response")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private extension BubbleAction {
    var engineDemoAction: WhaleyAdventureAction? {
        switch self {
        case .shootLeft: .shootLeft
        case .shootRight: .shootRight
        case .shootBelow: .shootBelow
        }
    }
}
