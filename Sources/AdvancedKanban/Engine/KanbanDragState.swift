import CoreGraphics
import Observation

/// In-progress drag state, observed by the view layer. Plain Swift — not a
/// `View` — so `KanbanDragStateTests` exercises it without hosting any view
/// hierarchy.
@Observable
final class KanbanDragState<CardID: Hashable, ColumnID: Hashable> {
    private(set) var draggedCardID: CardID?
    private(set) var pointerLocation: CGPoint = .zero
    private(set) var proposedColumnID: ColumnID?
    private(set) var proposedIndex: Int?
    private(set) var dropDecision: WIPLimitDropDecision = .accept

    init() {}

    func beginDrag(cardID: CardID) {
        draggedCardID = cardID
    }

    func updatePointer(
        location: CGPoint,
        cardFrames: [KanbanCardFrame<CardID>],
        columnZones: [KanbanColumnZone<ColumnID>],
        cardColumns: [CardID: ColumnID],
        cardOrder: [ColumnID: [CardID]]
    ) {
        pointerLocation = location
        guard let resolved = KanbanInsertionResolver.resolve(
            pointerLocation: location,
            cardFrames: cardFrames,
            columnZones: columnZones,
            cardColumns: cardColumns,
            cardOrder: cardOrder
        ) else {
            return
        }
        proposedColumnID = resolved.columnID
        proposedIndex = resolved.index
    }

    func setDropDecision(_ decision: WIPLimitDropDecision) {
        dropDecision = decision
    }

    func endDrag() {
        draggedCardID = nil
        pointerLocation = .zero
        proposedColumnID = nil
        proposedIndex = nil
        dropDecision = .accept
    }
}
