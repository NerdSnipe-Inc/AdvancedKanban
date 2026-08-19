import SwiftUI

/// Shared named coordinate space for all frame reporting/hit-testing across
/// `KanbanBoard`, `KanbanColumnView`, and `KanbanCardView`.
enum KanbanCoordinateSpace {
    static let name = "AdvancedKanban.board"
}

/// Renders one card's chrome (background, border, corner radius, shadow,
/// drag/WIP-warning state styling) around consumer-supplied content, and
/// reports its own frame via `KanbanFramePreferenceKey` so the drag engine
/// can hit-test against it.
public struct KanbanCardView<Card: KanbanCard, Content: View>: View {
    @Environment(\.kanbanTheme) private var theme

    let card: Card
    let columnID: AnyHashable
    let isBeingDragged: Bool
    let isOverWIPWarning: Bool
    @ViewBuilder let content: (Card) -> Content

    public init(
        card: Card,
        columnID: AnyHashable,
        isBeingDragged: Bool,
        isOverWIPWarning: Bool,
        @ViewBuilder content: @escaping (Card) -> Content
    ) {
        self.card = card
        self.columnID = columnID
        self.isBeingDragged = isBeingDragged
        self.isOverWIPWarning = isOverWIPWarning
        self.content = content
    }

    public var body: some View {
        content(card)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .strokeBorder(isOverWIPWarning ? theme.wipLimitWarningColor : theme.cardBorder, lineWidth: isOverWIPWarning ? 2 : 1)
            )
            .opacity(isBeingDragged ? 0 : 1) // real card hides; ghost overlay stands in
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: KanbanFramePreferenceKey.self,
                        value: [.card(AnyHashable(card.id), proxy.frame(in: .named(KanbanCoordinateSpace.name)))]
                    )
                }
            )
    }
}
