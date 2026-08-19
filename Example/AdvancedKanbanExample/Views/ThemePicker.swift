import SwiftUI
import AdvancedKanban

enum ExampleTheme: String, CaseIterable, Identifiable {
    case standard, highContrast
    var id: String { rawValue }

    /// The package only owns card chrome (background/border/shadow) — content styling,
    /// including text color, is the consumer's responsibility (spec §9). Each theme here
    /// pairs its `cardBackground` with an explicit, legible title color rather than relying
    /// on `.primary`, which silently breaks (white-on-white) once a theme sets a fixed
    /// light card background under a dark system appearance.
    var cardTitleColor: Color {
        switch self {
        case .standard: .primary
        case .highContrast: .black
        }
    }

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
