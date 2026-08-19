import SwiftUI
import AdvancedKanban

enum ExampleTheme: String, CaseIterable, Identifiable {
    case standard, highContrast
    var id: String { rawValue }

    var kanbanTheme: KanbanTheme {
        switch self {
        case .standard:
            .default
        case .highContrast:
            KanbanTheme(
                columnBackground: .black,
                cardBackground: .white,
                cardBorder: .yellow,
                cardCornerRadius: 4,
                cardSpacing: 10,
                columnWidth: 300,
                columnCornerRadius: 6,
                wipLimitWarningColor: .red,
                dragGhostOpacity: 1.0,
                dropAnimation: .easeInOut(duration: 0.2)
            )
        }
    }
}

struct ThemePicker: View {
    @Binding var selection: ExampleTheme

    var body: some View {
        Picker("Theme", selection: $selection) {
            ForEach(ExampleTheme.allCases) { theme in
                Text(theme == .standard ? "Standard" : "High Contrast").tag(theme)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}
