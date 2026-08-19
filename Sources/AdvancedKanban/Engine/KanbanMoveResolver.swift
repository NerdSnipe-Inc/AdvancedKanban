/// Resolves a candidate (source, destination) pair into a `KanbanMove`,
/// or `nil` if the move is a no-op.
///
/// This is the single source of truth for "what does moving a card here
/// mean" — pointer drag, keyboard move-mode, and VoiceOver actions all call
/// this function so their behavior can never diverge.
enum KanbanMoveResolver {
    /// - Parameters:
    ///   - sourceIndex: The card's current index in its source column.
    ///   - destinationIndex: An **insertion slot** index, measured *before*
    ///     the card is removed from its source column — not the target
    ///     position the card should end up at. For a same-column forward
    ///     move this matters: to move a card from index `i` down by one
    ///     position, pass `i + 2` (slot "after the card that currently
    ///     follows it"), because this function decrements a same-column
    ///     forward destination by one to account for the removal shifting
    ///     later indices down. Passing `i + 1` names the slot the card
    ///     already occupies and therefore resolves to `nil`.
    /// - Returns: A resolved move, or `nil` when the move is a no-op —
    ///   either because the caller asked for the card's current position,
    ///   or because the insertion slot resolves to it after adjustment.
    static func resolve<CardID: Hashable, ColumnID: Hashable>(
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

        // The pre-adjustment no-op check above can't catch a slot that only
        // becomes a no-op *after* adjustment (e.g. slot `i + 1` for a card at
        // index `i`). Without this second guard the caller gets a spurious
        // same-position `KanbanMove` and `onMove` fires for nothing.
        if sourceColumnID == destinationColumnID && adjustedDestinationIndex == sourceIndex {
            return nil
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
