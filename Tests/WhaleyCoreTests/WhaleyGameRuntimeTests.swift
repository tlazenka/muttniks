import Testing

@testable import WhaleyCore

@Test func tileLookupUsesTheSameConcreteRepresentationHeadlessly() {
    let layer = TileLayer(width: 3, height: 2, gids: [1, 2, 3, 4, 5, 6])
    let map = TileMap(size: .init(width: 3, height: 2), tileSize: .init(width: 32, height: 32), layers: ["Meta": layer])
    #expect(map.gid(in: "Meta", at: .init(column: 1, row: 1)) == 5)
    #expect(map.gid(in: "Meta", at: .init(column: -1, row: 0)) == 0)
}

@Test func actionIsAValueBeforeItIsRendered() {
    let action: GameAction = .sequence([
        .scale(to: 0.1, duration: .seconds(0)),
        .move(to: .init(x: 33, y: 80), duration: .seconds(0.25)),
        .wait(.seconds(0.5)),
    ])
    #expect(
        action
            == .sequence([
                .scale(to: 0.1, duration: .seconds(0)),
                .move(to: .init(x: 33, y: 80), duration: .seconds(0.25)),
                .wait(.seconds(0.5)),
            ])
    )
}

@Test func headlessClockIsExplicitAndDeterministic() {
    var scene = GameScene()
    scene.advance(by: .seconds(0.016))
    scene.advance(by: .seconds(0.016))
    #expect(scene.elapsed == .init(microseconds: 32_000))
}

@Test func tileMapUsesOneConcreteLayerRepresentation() {
    let layer = TileLayer(width: 3, height: 2, gids: [1, 2, 3, 4, 5, 6])
    let map = TileMap(
        size: .init(width: 3, height: 2),
        tileSize: .init(width: 32, height: 32),
        layers: ["Meta": layer]
    )
    #expect(map.gid(in: "Meta", at: .init(column: 0, row: 0)) == 1)
    #expect(map.gid(in: "Meta", at: .init(column: 2, row: 1)) == 6)
    #expect(map.gid(in: "Meta", at: .init(column: -1, row: 0)) == 0)
    #expect(map.gid(in: "Missing", at: .init(column: 0, row: 0)) == 0)
}

@Test func schedulerFiresFromDeterministicElapsedTimeNotFrameCount() {
    var scheduler = GameScheduler()
    _ = scheduler.schedule(callback: 32, every: .seconds(0.5))
    #expect(scheduler.advance(by: .seconds(0.49)).isEmpty)
    #expect(scheduler.advance(by: .seconds(0.01)) == [32])
    #expect(scheduler.advance(by: .seconds(1.0)) == [32, 32])
    #expect(scheduler.elapsed == .seconds(1.5))
}

@Test func schedulerPreservesChronologicalOrderAcrossLargeTicks() {
    var scheduler = GameScheduler()
    _ = scheduler.schedule(callback: 2, every: .seconds(1.0))
    _ = scheduler.schedule(callback: 1, every: .seconds(0.5))
    #expect(scheduler.advance(by: .seconds(1.0)) == [1, 2, 1])
}

@Test func callbacksRemainSemanticInsideSequences() {
    let action: GameAction = .sequence([.wait(.seconds(0.25)), .callback(7)])
    #expect(action == .sequence([.wait(.seconds(0.25)), .callback(7)]))
}
