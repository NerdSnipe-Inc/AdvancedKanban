import SwiftData
import Foundation
import AdvancedKanban

@Model
public final class SwiftDataKanbanCard {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var sortIndex: Int
    public var column: SwiftDataKanbanColumn?

    public init(id: UUID = UUID(), title: String, sortIndex: Int) {
        self.id = id
        self.title = title
        self.sortIndex = sortIndex
    }
}

extension SwiftDataKanbanCard: KanbanCard {
    public static func == (lhs: SwiftDataKanbanCard, rhs: SwiftDataKanbanCard) -> Bool {
        lhs.id == rhs.id
    }
}
