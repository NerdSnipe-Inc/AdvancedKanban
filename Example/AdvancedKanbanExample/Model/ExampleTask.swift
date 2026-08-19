import Foundation
import AdvancedKanban

struct ExampleTask: KanbanCard {
    let id: UUID
    var title: String
    var assigneeInitials: String
    var priority: Priority

    enum Priority: String, CaseIterable {
        case low, medium, high

        var color: String {
            switch self {
            case .low: "green"
            case .medium: "orange"
            case .high: "red"
            }
        }
    }
}
