/// Resolves a candidate (source, destination) pair into a `KanbanMove`,
/// or `nil` if the move is a no-op.
///
/// This is the single source of truth for "what does moving a card here
/// mean" — pointer drag, keyboard move-mode, and VoiceOver actions all call
/// this function so their behavior can never diverge.
public enum KanbanMoveResolver {
    public static func resolve<CardID: Hashable, ColumnID: Hashable>(
        cardID: CardID,
        sourceColumnID: ColumnID,
        sourceIndex: Int,
        destinationColumnID: ColumnID,
        destinationIndex: Int
    ) -> KanbanMove<CardID, ColumnID>? {
        if sourceColumnID == destinationColumnID && sourceIndex == destinationIndex {
            return nil
        }

        // Within the same column, removing the card at `sourceIndex` shifts
        // every later index down by one before insertion happens — so a
        // forward move's destination must be decremented to land where the
        // caller actually intended.
        var adjustedDestinationIndex = destinationIndex
        if sourceColumnID == destinationColumnID && destinationIndex > sourceIndex {
            adjustedDestinationIndex -= 1
        }

        return KanbanMove(
            cardID: cardID,
            sourceColumnID: sourceColumnID,
            sourceIndex: sourceIndex,
            destinationColumnID: destinationColumnID,
            destinationIndex: adjustedDestinationIndex
        )
    }
}
