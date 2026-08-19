import SwiftUI

public struct KanbanColumnView<Column: KanbanColumn, CardContent: View, ColumnHeader: View, CardGesture: Gesture>: View {
    @Environment(\.kanbanTheme) private var theme

    let column: Column
    let draggedCardID: Column.Card.ID?
    let wipDecision: WIPLimitDropDecision
    let onToggleCollapse: () -> Void
    @ViewBuilder let cardContent: (Column.Card) -> CardContent
    @ViewBuilder let columnHeader: (Column) -> ColumnHeader
    let cardGesture: (Column.Card) -> CardGesture

    public init(
        column: Column,
        draggedCardID: Column.Card.ID?,
        wipDecision: WIPLimitDropDecision,
        onToggleCollapse: @escaping () -> Void,
        @ViewBuilder cardContent: @escaping (Column.Card) -> CardContent,
        @ViewBuilder columnHeader: @escaping (Column) -> ColumnHeader,
        cardGesture: @escaping (Column.Card) -> CardGesture
    ) {
        self.column = column
        self.draggedCardID = draggedCardID
        self.wipDecision = wipDecision
        self.onToggleCollapse = onToggleCollapse
        self.cardContent = cardContent
        self.columnHeader = columnHeader
        self.cardGesture = cardGesture
    }

    private var isOverWIPWarning: Bool {
        wipDecision == .acceptWithWarning
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !column.isCollapsed {
                cardList
            }
        }
        .frame(width: column.isCollapsed ? 56 : theme.columnWidth)
        .background(theme.columnBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.columnCornerRadius))
    }

    private var header: some View {
        HStack {
            columnHeader(column)
            Spacer()
            Text(wipCountText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOverWIPWarning ? theme.wipLimitWarningColor : .secondary)
            Button(action: onToggleCollapse) {
                Image(systemName: column.isCollapsed ? "chevron.right" : "chevron.down")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(column.isCollapsed ? "Expand column" : "Collapse column")
        }
        .padding(12)
    }

    private var wipCountText: String {
        if let limit = column.wipLimit {
            "\(column.cards.count)/\(limit)"
        } else {
            "\(column.cards.count)"
        }
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: theme.cardSpacing) {
                if column.cards.isEmpty {
                    emptyDropZonePlaceholder
                } else {
                    ForEach(column.cards) { card in
                        KanbanCardView(
                            card: card,
                            columnID: AnyHashable(column.id),
                            isBeingDragged: card.id == draggedCardID,
                            isOverWIPWarning: isOverWIPWarning,
                            content: cardContent
                        )
                        .gesture(cardGesture(card))
                    }
                }
            }
            .padding(12)
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: KanbanFramePreferenceKey.self,
                    value: [.columnZone(AnyHashable(column.id), proxy.frame(in: .named(KanbanCoordinateSpace.name)))]
                )
            }
        )
    }

    /// Keeps an empty column a valid, reachable drop target — without this,
    /// a column with zero cards has no frame to hit-test against.
    private var emptyDropZonePlaceholder: some View {
        RoundedRectangle(cornerRadius: theme.cardCornerRadius)
            .strokeBorder(theme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4]))
            .frame(height: 60)
            .overlay(Text("Drop here").font(.caption).foregroundStyle(.secondary))
    }
}
