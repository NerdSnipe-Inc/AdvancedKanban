import Foundation
import AdvancedKanban

struct ExampleColumn: KanbanColumn {
    let id: UUID
    var title: String
    var cards: [ExampleTask]
    var wipLimit: Int?
    var isCollapsed: Bool
}

extension ExampleColumn {
    static func seedData() -> [ExampleColumn] {
        [
            ExampleColumn(
                id: UUID(), title: "Backlog",
                cards: [
                    ExampleTask(id: UUID(), title: "Design onboarding flow", assigneeInitials: "JD", priority: .medium),
                    ExampleTask(id: UUID(), title: "Research competitor apps", assigneeInitials: "AS", priority: .low),
                ],
                wipLimit: nil, isCollapsed: false
            ),
            ExampleColumn(
                id: UUID(), title: "In Progress",
                cards: [
                    ExampleTask(id: UUID(), title: "Build KanbanBoard view", assigneeInitials: "JD", priority: .high),
                ],
                wipLimit: 3, isCollapsed: false
            ),
            ExampleColumn(
                id: UUID(), title: "Review",
                cards: [],
                wipLimit: 2, isCollapsed: false
            ),
            ExampleColumn(
                id: UUID(), title: "Done",
                cards: [
                    ExampleTask(id: UUID(), title: "Set up SPM package", assigneeInitials: "AS", priority: .low),
                ],
                wipLimit: nil, isCollapsed: false
            ),
        ]
    }
}
