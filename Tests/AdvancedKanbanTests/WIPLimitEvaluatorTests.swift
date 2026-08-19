import Testing
@testable import AdvancedKanban

@Suite struct WIPLimitEvaluatorTests {
    @Test func noLimitAlwaysAccepts() {
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: 100, wipLimit: nil,
            behavior: .preventDrop, isMovingWithinSameColumn: false
        )
        #expect(decision == .accept)
    }

    @Test func underLimitAccepts() {
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: 2, wipLimit: 5,
            behavior: .preventDrop, isMovingWithinSameColumn: false
        )
        #expect(decision == .accept)
    }

    @Test func crossColumnDropExceedingLimitWithWarnOnlyAcceptsWithWarning() {
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: 5, wipLimit: 5,
            behavior: .warnOnly, isMovingWithinSameColumn: false
        )
        #expect(decision == .acceptWithWarning)
    }

    @Test func crossColumnDropExceedingLimitWithPreventDropRejects() {
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: 5, wipLimit: 5,
            behavior: .preventDrop, isMovingWithinSameColumn: false
        )
        #expect(decision == .reject)
    }

    @Test func reorderWithinSameColumnDoesNotCountTheMovingCardTwice() {
        // The card being moved is already counted in destinationCardCount
        // when the move stays within the same column, so a column exactly
        // at its limit should not be treated as "over" for a same-column
        // reorder.
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: 5, wipLimit: 5,
            behavior: .preventDrop, isMovingWithinSameColumn: true
        )
        #expect(decision == .accept)
    }
}
