import Testing
@testable import AdvancedKanban

/// NOTE (wiring, not logic): the evaluator below was always correct — the
/// shipped bug was that only the pointer-drag path consulted it, so keyboard
/// and VoiceOver moves bypassed `.preventDrop` entirely. That seam lives in
/// `KanbanBoard.swift` on a generic SwiftUI `View`, so it isn't unit-testable
/// here; it is enforced structurally instead. `KanbanBoard` has exactly one
/// WIP gate — `wipDecision(destinationColumn:isMovingWithinSameColumn:)` —
/// and both `updateWIPDecision` (pointer drag) and `moveCard` (keyboard +
/// VoiceOver) call it, each bailing out on `.reject` before `applyMove`.
/// If you add a fourth input path, route it through that helper too.
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
