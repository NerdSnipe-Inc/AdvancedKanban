import SwiftUI

struct TaskCardContent: View {
    let task: ExampleTask

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.subheadline.weight(.medium))
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
