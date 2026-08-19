import Testing
@testable import AdvancedKanban

@Suite struct KanbanMoveResolverTests {
    @Test func sameColumnSameIndexResolvesToNil() {
        let move = KanbanMoveResolver.resolve(
            cardID: "a", sourceColumnID: "todo", sourceIndex: 1,
            destinationColumnID: "todo", destinationIndex: 1
        )
        #expect(move == nil)
    }

    @Test func crossColumnMovePreservesDestinationIndex() {
        let move = KanbanMoveResolver.resolve(
            cardID: "a", sourceColumnID: "todo", sourceIndex: 0,
            destinationColumnID: "doing", destinationIndex: 2
        )
        #expect(move == KanbanMove(cardID: "a", sourceColumnID: "todo", sourceIndex: 0, destinationColumnID: "doing", destinationIndex: 2))
    }

    @Test func sameColumnForwardMoveDecrementsDestinationIndex() {
        // Moving card at index 0 to "index 2" in the same column: once
        // removed, everything shifts down by one, so the effective landing
        // index is 1, not 2.
        let move = KanbanMoveResolver.resolve(
            cardID: "a", sourceColumnID: "todo", sourceIndex: 0,
            destinationColumnID: "todo", destinationIndex: 2
        )
        #expect(move?.destinationIndex == 1)
    }

    @Test func sameColumnBackwardMoveKeepsDestinationIndex() {
        let move = KanbanMoveResolver.resolve(
            cardID: "a", sourceColumnID: "todo", sourceIndex: 2,
            destinationColumnID: "todo", destinationIndex: 0
        )
        #expect(move?.destinationIndex == 0)
    }
}
