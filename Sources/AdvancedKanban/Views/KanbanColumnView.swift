import SwiftUI

struct KanbanColumnView<Column: KanbanColumn, CardContent: View, ColumnHeader: View, CardGesture: Gesture>: View {
    @Environment(\.kanbanTheme) private var theme

    @State private var moveModeCardID: Column.Card.ID?
    /// Where the card in move mode sat when move mode was entered, so
    /// `Escape` can put it back (spec §8: "Escape cancels and restores
    /// original position").
    @State private var moveModeOrigin: (columnID: Column.ID, index: Int)?
    @FocusState private var focusedCardID: Column.Card.ID?

    let column: Column
    let allColumns: [Column]
    let draggedCardID: Column.Card.ID?
    let wipDecision: WIPLimitDropDecision
    let columnTitle: ((Column) -> String)?
    let onToggleCollapse: () -> Void
    @ViewBuilder let cardContent: (Column.Card) -> CardContent
    @ViewBuilder let columnHeader: (Column) -> ColumnHeader
    let cardGesture: (Column.Card) -> CardGesture
    let moveCard: (_ cardID: Column.Card.ID, _ toColumnID: Column.ID, _ toIndex: Int) -> Void

    init(
        column: Column,
        allColumns: [Column],
        draggedCardID: Column.Card.ID?,
        wipDecision: WIPLimitDropDecision,
        columnTitle: ((Column) -> String)? = nil,
        onToggleCollapse: @escaping () -> Void,
        @ViewBuilder cardContent: @escaping (Column.Card) -> CardContent,
        @ViewBuilder columnHeader: @escaping (Column) -> ColumnHeader,
        cardGesture: @escaping (Column.Card) -> CardGesture,
        moveCard: @escaping (_ cardID: Column.Card.ID, _ toColumnID: Column.ID, _ toIndex: Int) -> Void
    ) {
        self.column = column
        self.allColumns = allColumns
        self.draggedCardID = draggedCardID
        self.wipDecision = wipDecision
        self.columnTitle = columnTitle
        self.onToggleCollapse = onToggleCollapse
        self.cardContent = cardContent
        self.columnHeader = columnHeader
        self.cardGesture = cardGesture
        self.moveCard = moveCard
    }

    private var isOverWIPWarning: Bool {
        wipDecision == .acceptWithWarning
    }

    var body: some View {
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
                    ForEach(Array(column.cards.enumerated()), id: \.element.id) { index, card in
                        KanbanCardView(
                            card: card,
                            columnID: AnyHashable(column.id),
                            isBeingDragged: card.id == draggedCardID,
                            isOverWIPWarning: isOverWIPWarning,
                            content: cardContent
                        )
                        .gesture(cardGesture(card))
                        .accessibilityElement(children: .combine)
                        .accessibilityValue("\(index + 1) of \(column.cards.count) in \(accessibilityColumnTitle)")
                        .accessibilityAction(named: "Move Up") {
                            guard index > 0 else { return }
                            moveCard(card.id, column.id, index - 1)
                        }
                        .accessibilityAction(named: "Move Down") {
                            guard index < column.cards.count - 1 else { return }
                            // `moveCard` takes an insertion *slot* (pre-removal);
                            // slot `index + 1` is the one this card already
                            // occupies, so moving one position down is `index + 2`.
                            moveCard(card.id, column.id, index + 2)
                        }
                        .accessibilityActions {
                            ForEach(allColumns.filter { $0.id != column.id }) { otherColumn in
                                Button("Move to \(accessibilityTitle(for: otherColumn))") {
                                    moveCard(card.id, otherColumn.id, otherColumn.cards.count)
                                }
                            }
                        }
                        .focusable()
                        .focused($focusedCardID, equals: card.id)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                                .strokeBorder(theme.wipLimitWarningColor, lineWidth: moveModeCardID == card.id ? 2 : 0)
                        )
                        .onKeyPress(.space) {
                            toggleMoveMode(for: card.id, at: index)
                            return .handled
                        }
                        .onKeyPress(.return) {
                            if moveModeCardID == card.id {
                                exitMoveMode()
                                return .handled
                            }
                            toggleMoveMode(for: card.id, at: index)
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            guard moveModeCardID == card.id else { return .ignored }
                            cancelMoveMode(for: card.id, currentIndex: index)
                            return .handled
                        }
                        .onKeyPress(.upArrow) {
                            guard moveModeCardID == card.id, index > 0 else { return .ignored }
                            moveCard(card.id, column.id, index - 1)
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            guard moveModeCardID == card.id, index < column.cards.count - 1 else { return .ignored }
                            // Insertion-slot convention: `index + 1` is this
                            // card's own slot, so one position down is `index + 2`.
                            moveCard(card.id, column.id, index + 2)
                            return .handled
                        }
                        .onKeyPress(.leftArrow) {
                            guard moveModeCardID == card.id, let previousColumn = column(before: column) else { return .ignored }
                            moveCard(card.id, previousColumn.id, previousColumn.cards.count)
                            exitMoveMode()
                            return .handled
                        }
                        .onKeyPress(.rightArrow) {
                            guard moveModeCardID == card.id, let nextColumn = column(after: column) else { return .ignored }
                            moveCard(card.id, nextColumn.id, nextColumn.cards.count)
                            exitMoveMode()
                            return .handled
                        }
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

    private var accessibilityColumnTitle: String {
        accessibilityTitle(for: column)
    }

    private func accessibilityTitle(for column: Column) -> String {
        if let columnTitle {
            return columnTitle(column)
        }
        return "column \(String(describing: column.id))"
    }

    private func toggleMoveMode(for cardID: Column.Card.ID, at index: Int) {
        if moveModeCardID == cardID {
            exitMoveMode()
        } else {
            moveModeCardID = cardID
            moveModeOrigin = (columnID: column.id, index: index)
        }
    }

    /// Leaves move mode, keeping whatever position the card has reached
    /// (`Return` commits; a cross-column arrow also ends the session).
    private func exitMoveMode() {
        moveModeCardID = nil
        moveModeOrigin = nil
    }

    /// Leaves move mode and puts the card back where it started.
    private func cancelMoveMode(for cardID: Column.Card.ID, currentIndex: Int) {
        if let origin = moveModeOrigin,
           origin.columnID != column.id || origin.index != currentIndex {
            // `moveCard` takes an insertion slot measured before removal, so
            // a restore that moves the card *forward* needs origin.index + 1.
            let slot = (origin.columnID == column.id && origin.index > currentIndex)
                ? origin.index + 1
                : origin.index
            moveCard(cardID, origin.columnID, slot)
        }
        exitMoveMode()
    }

    private func column(before target: Column) -> Column? {
        guard let index = allColumns.firstIndex(where: { $0.id == target.id }), index > 0 else { return nil }
        return allColumns[index - 1]
    }

    private func column(after target: Column) -> Column? {
        guard let index = allColumns.firstIndex(where: { $0.id == target.id }), index < allColumns.count - 1 else { return nil }
        return allColumns[index + 1]
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
