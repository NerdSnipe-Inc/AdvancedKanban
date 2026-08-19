import CoreGraphics

/// Resolves which column and index a dragged card should land at, given the
/// pointer's current location in the board's coordinate space.
enum KanbanInsertionResolver {
    /// Uses each card's frame **midpoint** — not its edge — as the crossing
    /// threshold. Comparing against the edge causes the insertion index to
    /// flicker as the pointer hovers near a card boundary; the midpoint
    /// comparison is stable because the pointer has to cross half the card's
    /// height before the index changes.
    static func resolve<CardID: Hashable, ColumnID: Hashable>(
        pointerLocation: CGPoint,
        cardFrames: [KanbanCardFrame<CardID>],
        columnZones: [KanbanColumnZone<ColumnID>],
        cardColumns: [CardID: ColumnID],
        cardOrder: [ColumnID: [CardID]]
    ) -> (columnID: ColumnID, index: Int)? {
        guard let targetColumn = columnZones.first(where: { $0.frame.contains(pointerLocation) })
            ?? nearestColumn(to: pointerLocation, in: columnZones)
        else {
            return nil
        }

        let orderedCardIDs = cardOrder[targetColumn.columnID] ?? []
        let framesInColumn = orderedCardIDs.compactMap { id in
            cardFrames.first(where: { $0.cardID == id })
        }

        var index = framesInColumn.count
        for (i, cardFrame) in framesInColumn.enumerated() {
            if pointerLocation.y < cardFrame.frame.midY {
                index = i
                break
            }
        }
        return (targetColumn.columnID, index)
    }

    private static func nearestColumn<ColumnID: Hashable>(
        to point: CGPoint,
        in zones: [KanbanColumnZone<ColumnID>]
    ) -> KanbanColumnZone<ColumnID>? {
        zones.min { distance(from: point, to: $0.frame) < distance(from: point, to: $1.frame) }
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
