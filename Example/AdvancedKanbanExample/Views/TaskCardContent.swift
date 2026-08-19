import SwiftUI

struct TaskCardContent: View {
    let task: ExampleTask
    var titleColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(titleColor)
            HStack {
                Text(task.priority.rawValue.capitalized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor.opacity(0.15))
                    .foregroundStyle(priorityColor)
                    .clipShape(Capsule())
                Spacer()
                Text(task.assigneeInitials)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.gray.opacity(0.2)))
            }
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}

#Preview("Low priority", traits: .sizeThatFitsLayout) {
    TaskCardContent(
        task: ExampleTask(id: UUID(), title: "Research competitor apps", assigneeInitials: "AS", priority: .low)
    )
    .padding()
}

#Preview("Medium priority", traits: .sizeThatFitsLayout) {
    TaskCardContent(
        task: ExampleTask(id: UUID(), title: "Design onboarding flow", assigneeInitials: "JD", priority: .medium)
    )
    .padding()
}

#Preview("High priority, long title", traits: .sizeThatFitsLayout) {
    TaskCardContent(
        task: ExampleTask(id: UUID(), title: "Investigate the intermittent WebSocket disconnects on cellular", assigneeInitials: "JD", priority: .high)
    )
    .padding()
}

// High Contrast pairs a white card with an explicit black title — this preview
// exists specifically to catch the invisible-text regression class of bug
// (see git history: this exact mistake shipped once already).
#Preview("High Contrast card", traits: .sizeThatFitsLayout) {
    TaskCardContent(
        task: ExampleTask(id: UUID(), title: "Build KanbanBoard view", assigneeInitials: "JD", priority: .high),
        titleColor: .black
    )
    .padding()
    .background(Color.white)
}
