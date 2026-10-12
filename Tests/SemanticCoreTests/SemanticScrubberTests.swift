import SemanticCore
import Testing

@Test func scrubStepsAndClamping() {
    let scrub = SemanticScrubInterpreter(pointsPerStep: 28)
    #expect(scrub.steps(for: 56) == 2)
    #expect(scrub.steps(for: -28) == -1)
    #expect(scrub.selectionIndex(translation: 1000, count: 4, origin: 1) == 3)
    #expect(scrub.selectionIndex(translation: -1000, count: 4, origin: 1) == 0)
}
