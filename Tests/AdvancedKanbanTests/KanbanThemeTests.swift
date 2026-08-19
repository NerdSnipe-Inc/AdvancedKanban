import Testing
import SwiftUI
@testable import AdvancedKanban

@Suite struct KanbanThemeTests {
    @Test func defaultThemeHasNonZeroCornerRadiusAndSpacing() {
        let theme = KanbanTheme.default
        #expect(theme.cardCornerRadius > 0)
        #expect(theme.cardSpacing > 0)
        #expect(theme.columnWidth > 0)
    }

    @Test func environmentDefaultsToDefaultTheme() {
        let values = EnvironmentValues()
        #expect(values.kanbanTheme.cardCornerRadius == KanbanTheme.default.cardCornerRadius)
    }
}
