import SwiftUI

// KanbanCoordinateSpace is declared in KanbanCardView.swift (Task 9) —
// reused here, not redeclared.

public struct KanbanBoard<Column: KanbanColumn, CardContent: View, ColumnHeader: View>: View {
    @Environment(\.kanbanTheme) private var theme
    @State private var dragState = KanbanDragState<Column.Card.ID, Column.ID>()
    @State private var cardFrames: [KanbanCardFrame<Column.Card.ID>] = []
    @State private var columnZones: [KanbanColumnZone<Column.ID>] = []
    @State private var draggedCardSize: CGSize = .zero

    @Binding var columns: [Column]
    let wipLimitBehavior: WIPLimitBehavior
    let onMove: ((KanbanMove<Column.Card.ID, Column.ID>) -> Void)?
    @ViewBuilder let cardContent: (Column.Card) -> CardContent
    @ViewBuilder let columnHeader: (Column) -> ColumnHeader

    public init(
        columns: Binding<[Column]>,
        wipLimitBehavior: WIPLimitBehavior = .warnOnly,
        onMove: ((KanbanMove<Column.Card.ID, Column.ID>) -> Void)? = nil,
        @ViewBuilder cardContent: @escaping (Column.Card) -> CardContent,
        @ViewBuilder columnHeader: @escaping (Column) -> ColumnHeader
    ) {
        self._columns = columns
        self.wipLimitBehavior = wipLimitBehavior
        self.onMove = onMove
        self.cardContent = cardContent
        self.columnHeader = columnHeader
    }

    private var cardColumns: [Column.Card.ID: Column.ID] {
        var map: [Column.Card.ID: Column.ID] = [:]
        for column in columns {
            for card in column.cards {
                map[card.id] = column.id
            }
        }
        return map
    }

    private var cardOrder: [Column.ID: [Column.Card.ID]] {
        Dictionary(uniqueKeysWithValues: columns.map { ($0.id, $0.cards.map(\.id)) })
    }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: theme.cardSpacing * 2) {
                ForEach(columns) { column in
                    KanbanColumnView(
                        column: column,
                        draggedCardID: dragState.draggedCardID,
                        wipDecision: wipDecision(for: column),
                        onToggleCollapse: { toggleCollapse(columnID: column.id) },
                        cardContent: cardContent,
                        columnHeader: columnHeader,
                        cardGesture: { card in dragGesture(for: card, in: column) }
                    )
                }
            }
            .padding(theme.cardSpacing * 2)
        }
        .coordinateSpace(name: KanbanCoordinateSpace.name)
        .onPreferenceChange(KanbanFramePreferenceKey.self) { frames in
            // KanbanFramePreferenceKey carries type-erased AnyHashable ids
            // (see Task 7) because KanbanCardView doesn't know Column.ID.
            // KanbanBoard is the one place that knows the concrete types,
            // so it casts back here.
            cardFrames = frames.compactMap { frame in
                if case let .card(id, rect) = frame, let cardID = id.base as? Column.Card.ID {
                    return KanbanCardFrame(cardID: cardID, frame: rect)
                }
                return nil
            }
            columnZones = frames.compactMap { frame in
                if case let .columnZone(id, rect) = frame, let columnID = id.base as? Column.ID {
                    return KanbanColumnZone(columnID: columnID, frame: rect)
                }
                return nil
            }
        }
        .overlay(alignment: .topLeading) {
            if let draggedCardID = dragState.draggedCardID,
               let card = columns.flatMap(\.cards).first(where: { $0.id == draggedCardID }) {
                KanbanDragGhostOverlay(
                    content: cardContent(card),
                    position: dragState.pointerLocation,
                    size: draggedCardSize
                )
            }
        }
    }

    private func wipDecision(for column: Column) -> WIPLimitDropDecision {
        guard dragState.draggedCardID != nil, dragState.proposedColumnID == column.id else {
            return .accept
        }
        return dragState.dropDecision
    }

    private func toggleCollapse(columnID: Column.ID) {
        guard let index = columns.firstIndex(where: { $0.id == columnID }) else { return }
        columns[index].isCollapsed.toggle()
    }

    private func dragGesture(for card: Column.Card, in column: Column) -> some Gesture {
        DragGesture(coordinateSpace: .named(KanbanCoordinateSpace.name))
            .onChanged { value in
                if dragState.draggedCardID == nil {
                    dragState.beginDrag(cardID: card.id)
                    draggedCardSize = cardFrames.first(where: { $0.cardID == card.id })?.frame.size ?? .zero
                }
                dragState.updatePointer(
                    location: value.location,
                    cardFrames: cardFrames,
                    columnZones: columnZones,
                    cardColumns: cardColumns,
                    cardOrder: cardOrder
                )
                updateWIPDecision(for: card, in: column)
            }
            .onEnded { _ in
                commitDrag(for: card, from: column)
                dragState.endDrag()
            }
    }

    private func updateWIPDecision(for card: Column.Card, in sourceColumn: Column) {
        guard let destinationColumnID = dragState.proposedColumnID,
              let destinationColumn = columns.first(where: { $0.id == destinationColumnID })
        else { return }
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: destinationColumn.cards.count,
            wipLimit: destinationColumn.wipLimit,
            behavior: wipLimitBehavior,
            isMovingWithinSameColumn: destinationColumnID == sourceColumn.id
        )
        dragState.setDropDecision(decision)
    }

    private func commitDrag(for card: Column.Card, from sourceColumn: Column) {
        guard let destinationColumnID = dragState.proposedColumnID,
              let destinationIndex = dragState.proposedIndex,
              let sourceIndex = sourceColumn.cards.firstIndex(where: { $0.id == card.id })
        else { return }

        if dragState.dropDecision == .reject {
            return // snap back: no mutation, theme.dropAnimation covers the visual return
        }

        guard let move = KanbanMoveResolver.resolve(
            cardID: card.id,
            sourceColumnID: sourceColumn.id,
            sourceIndex: sourceIndex,
            destinationColumnID: destinationColumnID,
            destinationIndex: destinationIndex
        ) else {
            return
        }

        applyMove(move)
        onMove?(move)
    }

    /// Applies a resolved `KanbanMove` to the local `columns` binding.
    /// Both the drag-gesture path (above) and keyboard/VoiceOver paths
    /// (Tasks 12–13) call this so mutation logic exists in exactly one
    /// place.
    func applyMove(_ move: KanbanMove<Column.Card.ID, Column.ID>) {
        guard let sourceColumnIndex = columns.firstIndex(where: { $0.id == move.sourceColumnID }),
              let card = columns[sourceColumnIndex].cards.first(where: { $0.id == move.cardID })
        else { return }

        withAnimation(theme.dropAnimation) {
            columns[sourceColumnIndex].cards.removeAll { $0.id == move.cardID }
            guard let destinationColumnIndex = columns.firstIndex(where: { $0.id == move.destinationColumnID }) else { return }
            let clampedIndex = min(max(move.destinationIndex, 0), columns[destinationColumnIndex].cards.count)
            columns[destinationColumnIndex].cards.insert(card, at: clampedIndex)
        }
    }
}
