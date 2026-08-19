/// Describes a single card move, emitted by `KanbanBoard` via `onMove`
/// after the board's local `columns` binding has already been mutated.
///
/// Consumers use this to persist the change (SwiftData save, network
/// call, analytics) without needing to diff arrays themselves.
public struct KanbanMove<CardID: Hashable, ColumnID: Hashable>: Equatable {
    public let cardID: CardID
    public let sourceColumnID: ColumnID
    public let sourceIndex: Int
    public let destinationColumnID: ColumnID
    public let destinationIndex: Int

    public init(
        cardID: CardID,
        sourceColumnID: ColumnID,
        sourceIndex: Int,
        destinationColumnID: ColumnID,
        destinationIndex: Int
    ) {
        self.cardID = cardID
        self.sourceColumnID = sourceColumnID
        self.sourceIndex = sourceIndex
        self.destinationColumnID = destinationColumnID
        self.destinationIndex = destinationIndex
    }
}
