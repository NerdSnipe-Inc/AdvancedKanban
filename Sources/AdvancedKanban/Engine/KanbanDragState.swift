import CoreGraphics
import Observation

/// In-progress drag state, observed by the view layer. Plain Swift — not a
/// `View` — so `KanbanDragStateTests` exercises it without hosting any view
/// hierarchy.
@Observable
public final class KanbanDragState<CardID: Hashable, ColumnID: Hashable> {
    public private(set) var draggedCardID: CardID?
    public private(set) var pointerLocation: CGPoint = .zero
    public private(set) var proposedColumnID: ColumnID?
    public private(set) var proposedIndex: Int?
    public private(set) var dropDecision: WIPLimitDropDecision = .accept

    public init() {}

    public func beginDrag(cardID: CardID) {
        draggedCardID = cardID
    }

    public func updatePointer(
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

    public func setDropDecision(_ decision: WIPLimitDropDecision) {
        dropDecision = decision
    }

    public func endDrag() {
        draggedCardID = nil
        pointerLocation = .zero
        proposedColumnID = nil
        proposedIndex = nil
        dropDecision = .accept
    }
}
