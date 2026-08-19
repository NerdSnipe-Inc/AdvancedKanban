import Testing
import CoreGraphics
@testable import AdvancedKanban

@Suite struct KanbanAutoscrollTests {
    @Test func pointerInTheMiddleProducesNoScroll() {
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: 500, bounds: 0...1000, edgeBand: 50, maxSpeed: 20
        )
        #expect(direction == .none)
    }

    @Test func pointerAtLowerEdgeProducesMaxNegativeSpeed() {
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: 0, bounds: 0...1000, edgeBand: 50, maxSpeed: 20
        )
        #expect(direction == .negative(magnitude: 20))
    }

    @Test func pointerAtUpperEdgeProducesMaxPositiveSpeed() {
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: 1000, bounds: 0...1000, edgeBand: 50, maxSpeed: 20
        )
        #expect(direction == .positive(magnitude: 20))
    }

    @Test func pointerHalfwayThroughLowerBandProducesHalfSpeed() {
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: 25, bounds: 0...1000, edgeBand: 50, maxSpeed: 20
        )
        #expect(direction == .negative(magnitude: 10))
    }

    @Test func pointerOutsideBoundsEntirelyProducesNoScroll() {
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: -50, bounds: 0...1000, edgeBand: 50, maxSpeed: 20
        )
        #expect(direction == .none)
    }
}
