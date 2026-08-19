import SwiftData
import Foundation
import AdvancedKanban

@Model
public final class SwiftDataKanbanColumn {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var wipLimit: Int?
    public var isCollapsed: Bool

    @Relationship(deleteRule: .cascade, inverse: \SwiftDataKanbanCard.column)
    public var cardModels: [SwiftDataKanbanCard] = []

    public init(id: UUID = UUID(), title: String, wipLimit: Int?, isCollapsed: Bool) {
        self.id = id
        self.title = title
        self.wipLimit = wipLimit
        self.isCollapsed = isCollapsed
    }
}

extension SwiftDataKanbanColumn: KanbanColumn {
    public var cards: [SwiftDataKanbanCard] {
        get { cardModels.sorted { $0.sortIndex < $1.sortIndex } }
        set { cardModels = newValue }
    }
}
