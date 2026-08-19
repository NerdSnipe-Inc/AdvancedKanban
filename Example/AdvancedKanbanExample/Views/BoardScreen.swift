import SwiftUI
import AdvancedKanban

struct BoardScreen: View {
    @State private var columns = ExampleColumn.seedData()
    @State private var selectedTheme: ExampleTheme = .standard
    @State private var lastMoveDescription: String = "No moves yet"

    var body: some View {
        VStack(spacing: 12) {
            ThemePicker(selection: $selectedTheme)
            Text(lastMoveDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            KanbanBoard(
                columns: $columns,
                wipLimitBehavior: .preventDrop,
                onMove: { move in
                    lastMoveDescription = "Moved \(move.cardID) to column \(move.destinationColumnID) at index \(move.destinationIndex)"
                },
                cardContent: { task in TaskCardContent(task: task) },
                columnHeader: { column in
                    Text(column.title).font(.headline)
                }
            )
        }
        .kanbanTheme(selectedTheme.kanbanTheme)
        .padding(.top)
    }
}
