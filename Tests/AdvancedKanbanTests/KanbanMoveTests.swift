import Testing
@testable import AdvancedKanban

@Suite struct KanbanMoveTests {
    @Test func movesWithIdenticalFieldsAreEqual() {
        let a = KanbanMove(cardID: "card-1", sourceColumnID: "todo", sourceIndex: 0, destinationColumnID: "doing", destinationIndex: 1)
        let b = KanbanMove(cardID: "card-1", sourceColumnID: "todo", sourceIndex: 0, destinationColumnID: "doing", destinationIndex: 1)
        #expect(a == b)
    }

    @Test func movesWithDifferentDestinationsAreNotEqual() {
        let a = KanbanMove(cardID: "card-1", sourceColumnID: "todo", sourceIndex: 0, destinationColumnID: "doing", destinationIndex: 1)
        let b = KanbanMove(cardID: "card-1", sourceColumnID: "todo", sourceIndex: 0, destinationColumnID: "doing", destinationIndex: 2)
        #expect(a != b)
    }
}
