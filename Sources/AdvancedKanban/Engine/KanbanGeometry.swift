import CoreGraphics

/// A dragged-card-eligible card's on-screen frame, reported by
/// `KanbanCardView` via `KanbanFramePreferenceKey` in the board's named
/// coordinate space.
struct KanbanCardFrame<CardID: Hashable>: Equatable {
    let cardID: CardID
    let frame: CGRect

    init(cardID: CardID, frame: CGRect) {
        self.cardID = cardID
        self.frame = frame
    }
}

/// A column's drop-target frame (its full scrollable area, including when
/// the column has zero cards), reported the same way as `KanbanCardFrame`.
struct KanbanColumnZone<ColumnID: Hashable>: Equatable {
    let columnID: ColumnID
    let frame: CGRect

    init(columnID: ColumnID, frame: CGRect) {
        self.columnID = columnID
        self.frame = frame
    }
}
