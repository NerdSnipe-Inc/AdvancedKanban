import Testing
import SwiftData
import Foundation
@testable import AdvancedKanban
@testable import AdvancedKanbanSwiftData

@Suite struct KanbanStoreTests {
    @MainActor
    private func makeStore() throws -> (KanbanStore, ModelContext) {
        let schema = Schema([SwiftDataKanbanCard.self, SwiftDataKanbanColumn.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        return (KanbanStore(modelContext: context), context)
    }

    @MainActor
    @Test func applyingACrossColumnMoveReassignsTheCardsColumnAndSortIndex() throws {
        let (store, context) = try makeStore()

        let todo = SwiftDataKanbanColumn(id: UUID(), title: "Todo", wipLimit: nil, isCollapsed: false)
        let doing = SwiftDataKanbanColumn(id: UUID(), title: "Doing", wipLimit: nil, isCollapsed: false)
        let card = SwiftDataKanbanCard(id: UUID(), title: "Write tests", sortIndex: 0)
        card.column = todo
        context.insert(todo)
        context.insert(doing)
        context.insert(card)
        try context.save()

        let move = KanbanMove(
            cardID: card.id, sourceColumnID: todo.id, sourceIndex: 0,
            destinationColumnID: doing.id, destinationIndex: 0
        )
        try store.apply(move)

        #expect(card.column?.id == doing.id)
        #expect(card.sortIndex == 0)
    }
}
