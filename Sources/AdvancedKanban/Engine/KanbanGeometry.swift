import CoreGraphics

/// A dragged-card-eligible card's on-screen frame, reported by
/// `KanbanCardView` via `KanbanFramePreferenceKey` in the board's named
/// coordinate space.
public struct KanbanCardFrame<CardID: Hashable>: Equatable {
    public let cardID: CardID
    public let frame: CGRect

    public init(cardID: CardID, frame: CGRect) {
        self.cardID = cardID
        self.frame = frame
    }
}

/// A column's drop-target frame (its full scrollable area, including when
/// the column has zero cards), reported the same way as `KanbanCardFrame`.
public struct KanbanColumnZone<ColumnID: Hashable>: Equatable {
    public let columnID: ColumnID
    public let frame: CGRect

    public init(columnID: ColumnID, frame: CGRect) {
        self.columnID = columnID
        self.frame = frame
    }
}
