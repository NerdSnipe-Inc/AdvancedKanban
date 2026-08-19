import Testing
import CoreGraphics
@testable import AdvancedKanban

@Suite struct KanbanDragStateTests {
    @Test func beginDragSetsDraggedCardID() {
        let state = KanbanDragState<String, String>()
        state.beginDrag(cardID: "a")
        #expect(state.draggedCardID == "a")
    }

    @Test func updatePointerSetsProposedColumnAndIndex() {
        let state = KanbanDragState<String, String>()
        state.beginDrag(cardID: "a")
        state.updatePointer(
            location: CGPoint(x: 100, y: 10),
            cardFrames: [
                KanbanCardFrame(cardID: "a", frame: CGRect(x: 0, y: 0, width: 200, height: 50)),
                KanbanCardFrame(cardID: "b", frame: CGRect(x: 0, y: 50, width: 200, height: 50)),
            ],
            columnZones: [
                KanbanColumnZone(columnID: "todo", frame: CGRect(x: 0, y: 0, width: 200, height: 100)),
            ],
            cardColumns: ["a": "todo", "b": "todo"],
            cardOrder: ["todo": ["a", "b"]]
        )
        #expect(state.proposedColumnID == "todo")
        #expect(state.proposedIndex == 0)
    }

    @Test func endDragClearsAllState() {
        let state = KanbanDragState<String, String>()
        state.beginDrag(cardID: "a")
        state.endDrag()
        #expect(state.draggedCardID == nil)
        #expect(state.proposedColumnID == nil)
        #expect(state.proposedIndex == nil)
    }
}
