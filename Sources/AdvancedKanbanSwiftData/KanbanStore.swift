import SwiftData
import Foundation
import AdvancedKanban

public enum KanbanStoreError: Error {
    case cardNotFound
    case columnNotFound
}

@MainActor
public final class KanbanStore {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Applies a `KanbanMove` (as emitted by `KanbanBoard`'s `onMove`) to
    /// the SwiftData store: reassigns the card's column and renumbers
    /// `sortIndex` for every card in the destination column, then saves.
    public func apply(_ move: KanbanMove<UUID, UUID>) throws {
        let cardID = move.cardID
        let cardDescriptor = FetchDescriptor<SwiftDataKanbanCard>(
            predicate: #Predicate { $0.id == cardID }
        )
        guard let card = try modelContext.fetch(cardDescriptor).first else {
            throw KanbanStoreError.cardNotFound
        }

        let destinationColumnID = move.destinationColumnID
        let columnDescriptor = FetchDescriptor<SwiftDataKanbanColumn>(
            predicate: #Predicate { $0.id == destinationColumnID }
        )
        guard let destinationColumn = try modelContext.fetch(columnDescriptor).first else {
            throw KanbanStoreError.columnNotFound
        }

        var destinationCards = destinationColumn.cards.filter { $0.id != card.id }
        let clampedIndex = min(max(move.destinationIndex, 0), destinationCards.count)
        destinationCards.insert(card, at: clampedIndex)

        for (index, destinationCard) in destinationCards.enumerated() {
            destinationCard.sortIndex = index
            destinationCard.column = destinationColumn
        }

        try modelContext.save()
    }
}
