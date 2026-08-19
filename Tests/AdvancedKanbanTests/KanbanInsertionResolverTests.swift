import Testing
import CoreGraphics
@testable import AdvancedKanban

@Suite struct KanbanInsertionResolverTests {
    // Column "todo" has two cards stacked vertically: "a" at y 0-50, "b" at y 50-100.
    // Column "doing" is empty, occupying x 200-400, y 0-100.
    private func fixture() -> (
        cardFrames: [KanbanCardFrame<String>],
        columnZones: [KanbanColumnZone<String>],
        cardColumns: [String: String],
        cardOrder: [String: [String]]
    ) {
        let cardFrames = [
            KanbanCardFrame(cardID: "a", frame: CGRect(x: 0, y: 0, width: 200, height: 50)),
            KanbanCardFrame(cardID: "b", frame: CGRect(x: 0, y: 50, width: 200, height: 50)),
        ]
        let columnZones = [
            KanbanColumnZone(columnID: "todo", frame: CGRect(x: 0, y: 0, width: 200, height: 100)),
            KanbanColumnZone(columnID: "doing", frame: CGRect(x: 200, y: 0, width: 200, height: 100)),
        ]
        let cardColumns = ["a": "todo", "b": "todo"]
        let cardOrder = ["todo": ["a", "b"], "doing": []]
        return (cardFrames, columnZones, cardColumns, cardOrder)
    }

    @Test func pointerAboveFirstCardMidpointResolvesToIndexZero() {
        let f = fixture()
        let result = KanbanInsertionResolver.resolve(
            pointerLocation: CGPoint(x: 100, y: 10),
            cardFrames: f.cardFrames, columnZones: f.columnZones,
            cardColumns: f.cardColumns, cardOrder: f.cardOrder
        )
        #expect(result?.columnID == "todo")
        #expect(result?.index == 0)
    }

    @Test func pointerBetweenCardMidpointsResolvesToIndexOne() {
        let f = fixture()
        // Card "a" midpoint is y=25, card "b" midpoint is y=75. y=60 is past
        // "a"'s midpoint but before "b"'s — should insert at index 1.
        let result = KanbanInsertionResolver.resolve(
            pointerLocation: CGPoint(x: 100, y: 60),
            cardFrames: f.cardFrames, columnZones: f.columnZones,
            cardColumns: f.cardColumns, cardOrder: f.cardOrder
        )
        #expect(result?.columnID == "todo")
        #expect(result?.index == 1)
    }

    @Test func pointerPastLastCardMidpointResolvesToEndIndex() {
        let f = fixture()
        let result = KanbanInsertionResolver.resolve(
            pointerLocation: CGPoint(x: 100, y: 90),
            cardFrames: f.cardFrames, columnZones: f.columnZones,
            cardColumns: f.cardColumns, cardOrder: f.cardOrder
        )
        #expect(result?.columnID == "todo")
        #expect(result?.index == 2)
    }

    @Test func pointerOverEmptyColumnResolvesToIndexZero() {
        let f = fixture()
        let result = KanbanInsertionResolver.resolve(
            pointerLocation: CGPoint(x: 300, y: 50),
            cardFrames: f.cardFrames, columnZones: f.columnZones,
            cardColumns: f.cardColumns, cardOrder: f.cardOrder
        )
        #expect(result?.columnID == "doing")
        #expect(result?.index == 0)
    }

    @Test func pointerOutsideAllZonesResolvesToNearestColumn() {
        let f = fixture()
        // x=500 is past every zone; nearest is "doing" (x 200-400).
        let result = KanbanInsertionResolver.resolve(
            pointerLocation: CGPoint(x: 500, y: 50),
            cardFrames: f.cardFrames, columnZones: f.columnZones,
            cardColumns: f.cardColumns, cardOrder: f.cardOrder
        )
        #expect(result?.columnID == "doing")
    }
}
