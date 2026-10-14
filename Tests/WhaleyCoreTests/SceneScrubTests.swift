import Testing

@testable import WhaleyCore

@Test func gameClockCannotScrubBeforeLevelStart() {
    var clock = SceneTimeScrubSession(liveTime: .seconds(0.25))
    clock.update(horizontal: -96)
    #expect(clock.previewTime == .seconds(0))
}

@Test func objectScrubUsesTileSizedGestureSteps() {
    var scrub = SceneObjectScrubSession()
    scrub.update(horizontal: 64, vertical: 0)
    #expect(scrub.category == .position)
    #expect(scrub.scalarSteps == 2)

    scrub.update(horizontal: -32, vertical: 32)
    #expect(scrub.category == .size)
    #expect(scrub.scalarSteps == -1)

    scrub.update(horizontal: 32, vertical: 64)
    #expect(scrub.category == .image)
    #expect(scrub.scalarSteps == 1)
}

@Test func gameClockSemanticStepMatchesQuarterSecondAccessibilityIncrement() {
    var clock = SceneTimeScrubSession(liveTime: .seconds(4.25))
    clock.step(by: 1)
    #expect(clock.previewTime == .seconds(4.50))
    clock.step(by: -2)
    #expect(clock.previewTime == .seconds(4.00))
}

@Test func objectSceneScrubSupportsCoordinateFreeSemanticAdjustment() {
    var scrub = SceneObjectScrubSession()
    scrub.stepScalar(by: 1)
    #expect(scrub.category == .position)
    #expect(scrub.scalarSteps == 1)
    scrub.stepCategory(by: 1)
    #expect(scrub.category == .size)
    scrub.stepScalar(by: -2)
    #expect(scrub.scalarSteps == -1)
}
