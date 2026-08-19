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

    // MARK: - "Move Down" regression (keyboard + VoiceOver)
    //
    // `destinationIndex` is an *insertion slot* measured before the card is
    // removed. KanbanColumnView's "Move Down" action and `.downArrow`
    // handler used to pass `index + 1` — this card's own slot — which
    // adjusted back to `index` and made the move a silent no-op. They now
    // pass `index + 2`; these two tests pin both halves of that contract.

    @Test func moveDownOneSlotAdvancesCardByOnePosition() {
        // 3 cards [a, b, c]; move `b` (index 1) down one position.
        // Call site passes sourceIndex + 2 == 3.
        let sourceIndex = 1
        let move = KanbanMoveResolver.resolve(
            cardID: "b", sourceColumnID: "todo", sourceIndex: sourceIndex,
            destinationColumnID: "todo", destinationIndex: sourceIndex + 2
        )
        #expect(move != nil)
        #expect(move?.destinationIndex == sourceIndex + 1)
    }

    @Test func moveDownFromFirstSlotAdvancesCardByOnePosition() {
        let sourceIndex = 0
        let move = KanbanMoveResolver.resolve(
            cardID: "a", sourceColumnID: "todo", sourceIndex: sourceIndex,
            destinationColumnID: "todo", destinationIndex: sourceIndex + 2
        )
        #expect(move?.destinationIndex == sourceIndex + 1)
    }

    @Test func oldBrokenMoveDownSlotResolvesToNil() {
        // The pre-fix call (`index + 1`) names the slot the card already
        // occupies. It must resolve to nil rather than a spurious
        // same-position move that would still fire `onMove`.
        for sourceIndex in 0..<3 {
            let move = KanbanMoveResolver.resolve(
                cardID: "b", sourceColumnID: "todo", sourceIndex: sourceIndex,
                destinationColumnID: "todo", destinationIndex: sourceIndex + 1
            )
            #expect(move == nil)
        }
    }
}
