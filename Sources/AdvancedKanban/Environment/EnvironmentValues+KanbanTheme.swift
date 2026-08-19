import SwiftUI

private struct KanbanThemeKey: EnvironmentKey {
    static let defaultValue = KanbanTheme.default
}

extension EnvironmentValues {
    public var kanbanTheme: KanbanTheme {
        get { self[KanbanThemeKey.self] }
        set { self[KanbanThemeKey.self] = newValue }
    }
}

extension View {
    /// Applies a `KanbanTheme` to `KanbanBoard` (and any custom content
    /// that reads `@Environment(\.kanbanTheme)`) within this view subtree.
    public func kanbanTheme(_ theme: KanbanTheme) -> some View {
        environment(\.kanbanTheme, theme)
    }
}
