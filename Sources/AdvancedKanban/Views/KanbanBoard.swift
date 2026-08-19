import SwiftUI

// KanbanCoordinateSpace is declared in KanbanCardView.swift (Task 9) —
// reused here, not redeclared.

public struct KanbanBoard<Column: KanbanColumn, CardContent: View, ColumnHeader: View>: View {
    @Environment(\.kanbanTheme) private var theme
    @State private var dragState = KanbanDragState<Column.Card.ID, Column.ID>()
    @State private var cardFrames: [KanbanCardFrame<Column.Card.ID>] = []
    @State private var columnZones: [KanbanColumnZone<Column.ID>] = []
    @State private var draggedCardSize: CGSize = .zero
    @State private var boardBounds: CGRect = .zero
    @State private var autoscrollTimer: Timer?
    @State private var lastAutoscrollTargetColumnID: Column.ID?

    @Binding var columns: [Column]
    let wipLimitBehavior: WIPLimitBehavior
    let onMove: ((KanbanMove<Column.Card.ID, Column.ID>) -> Void)?
    let columnTitle: ((Column) -> String)?
    @ViewBuilder let cardContent: (Column.Card) -> CardContent
    @ViewBuilder let columnHeader: (Column) -> ColumnHeader

    /// - Parameter columnTitle: Supplies a human-readable name for a column,
    ///   used by VoiceOver ("Move to <Column Name>") and by each card's
    ///   accessibility value. Without it the board falls back to describing
    ///   the column by its `id`, which reads as a raw UUID for UUID-keyed
    ///   models — pass `{ $0.title }` (or whatever your column's name
    ///   property is) to get real names.
    public init(
        columns: Binding<[Column]>,
        wipLimitBehavior: WIPLimitBehavior = .warnOnly,
        onMove: ((KanbanMove<Column.Card.ID, Column.ID>) -> Void)? = nil,
        columnTitle: ((Column) -> String)? = nil,
        @ViewBuilder cardContent: @escaping (Column.Card) -> CardContent,
        @ViewBuilder columnHeader: @escaping (Column) -> ColumnHeader
    ) {
        self._columns = columns
        self.wipLimitBehavior = wipLimitBehavior
        self.onMove = onMove
        self.columnTitle = columnTitle
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
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: theme.cardSpacing * 2) {
                    ForEach(columns) { column in
                        KanbanColumnView(
                            column: column,
                            allColumns: columns,
                            draggedCardID: dragState.draggedCardID,
                            wipDecision: wipDecision(for: column),
                            columnTitle: columnTitle,
                            onToggleCollapse: { toggleCollapse(columnID: column.id) },
                            cardContent: cardContent,
                            columnHeader: columnHeader,
                            cardGesture: { card in dragGesture(for: card, in: column, scrollProxy: scrollProxy) },
                            moveCard: { cardID, toColumnID, toIndex in
                                moveCard(cardID: cardID, toColumnID: toColumnID, toIndex: toIndex)
                            }
                        )
                        .id(column.id)
                    }
                }
                .padding(theme.cardSpacing * 2)
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear { boardBounds = proxy.frame(in: .named(KanbanCoordinateSpace.name)) }
                        .onChange(of: proxy.size) { _, _ in boardBounds = proxy.frame(in: .named(KanbanCoordinateSpace.name)) }
                }
            )
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
            // Safety net: the drag gesture's `.onEnded` normally stops the
            // autoscroll timer, but a mid-drag teardown (navigation, sheet
            // dismissal, scene change) never delivers `.onEnded` and would
            // otherwise leak a repeating Timer.
            .onDisappear { stopAutoscroll() }
        }
    }

    private func wipDecision(for column: Column) -> WIPLimitDropDecision {
        guard dragState.draggedCardID != nil, dragState.proposedColumnID == column.id else {
            return .accept
        }
        return dragState.dropDecision
    }

    /// The single WIP-limit gate. Every input method — pointer drag
    /// (`updateWIPDecision` → `commitDrag`), keyboard move-mode, and
    /// VoiceOver actions (both via `moveCard`) — routes its check through
    /// here, so `.preventDrop` can never guard one path and not another.
    private func wipDecision(
        destinationColumn: Column,
        isMovingWithinSameColumn: Bool
    ) -> WIPLimitDropDecision {
        WIPLimitEvaluator.evaluate(
            destinationCardCount: destinationColumn.cards.count,
            wipLimit: destinationColumn.wipLimit,
            behavior: wipLimitBehavior,
            isMovingWithinSameColumn: isMovingWithinSameColumn
        )
    }

    /// The keyboard / VoiceOver move entry point. Mirrors `commitDrag`:
    /// consult the shared WIP gate, bail out on `.reject` without mutating
    /// or notifying, then resolve and apply.
    ///
    /// - Parameter toIndex: An insertion-slot index in the destination
    ///   column, using the same pre-removal convention as
    ///   `KanbanMoveResolver.resolve`.
    private func moveCard(cardID: Column.Card.ID, toColumnID: Column.ID, toIndex: Int) {
        guard let sourceColumn = columns.first(where: { $0.cards.contains(where: { $0.id == cardID }) }),
              let sourceIndex = sourceColumn.cards.firstIndex(where: { $0.id == cardID }),
              let destinationColumn = columns.first(where: { $0.id == toColumnID })
        else { return }

        let decision = wipDecision(
            destinationColumn: destinationColumn,
            isMovingWithinSameColumn: toColumnID == sourceColumn.id
        )
        if decision == .reject { return }

        guard let move = KanbanMoveResolver.resolve(
            cardID: cardID,
            sourceColumnID: sourceColumn.id,
            sourceIndex: sourceIndex,
            destinationColumnID: toColumnID,
            destinationIndex: toIndex
        ) else { return }

        applyMove(move)
        onMove?(move)
    }

    private func toggleCollapse(columnID: Column.ID) {
        guard let index = columns.firstIndex(where: { $0.id == columnID }) else { return }
        columns[index].isCollapsed.toggle()
    }

    private func startAutoscrollIfNeeded(scrollProxy: ScrollViewProxy) {
        guard autoscrollTimer == nil else { return }
        autoscrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 3.0, repeats: true) { _ in
            guard dragState.draggedCardID != nil, boardBounds.width > 0,
                  let currentColumnID = dragState.proposedColumnID,
                  let currentIndex = columns.firstIndex(where: { $0.id == currentColumnID })
            else { return }

            let direction = KanbanAutoscrollCalculator.direction(
                pointerPosition: dragState.pointerLocation.x,
                bounds: boardBounds.minX...boardBounds.maxX,
                edgeBand: 60,
                maxSpeed: 12
            )

            let targetColumn: Column?
            let anchor: UnitPoint
            switch direction {
            case .none:
                targetColumn = nil
                anchor = .leading
            case .negative:
                targetColumn = currentIndex > 0 ? columns[currentIndex - 1] : nil
                anchor = .leading
            case .positive:
                targetColumn = currentIndex < columns.count - 1 ? columns[currentIndex + 1] : nil
                anchor = .trailing
            }

            guard let targetColumn, targetColumn.id != lastAutoscrollTargetColumnID else { return }
            lastAutoscrollTargetColumnID = targetColumn.id
            withAnimation(.easeOut(duration: 0.3)) {
                scrollProxy.scrollTo(targetColumn.id, anchor: anchor)
            }
        }
    }

    private func stopAutoscroll() {
        autoscrollTimer?.invalidate()
        autoscrollTimer = nil
        lastAutoscrollTargetColumnID = nil
    }

    private func dragGesture(for card: Column.Card, in column: Column, scrollProxy: ScrollViewProxy) -> some Gesture {
        DragGesture(coordinateSpace: .named(KanbanCoordinateSpace.name))
            .onChanged { value in
                if dragState.draggedCardID == nil {
                    dragState.beginDrag(cardID: card.id)
                    draggedCardSize = cardFrames.first(where: { $0.cardID == card.id })?.frame.size ?? .zero
                    startAutoscrollIfNeeded(scrollProxy: scrollProxy)
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
                stopAutoscroll()
            }
    }

    private func updateWIPDecision(for card: Column.Card, in sourceColumn: Column) {
        guard let destinationColumnID = dragState.proposedColumnID,
              let destinationColumn = columns.first(where: { $0.id == destinationColumnID })
        else { return }
        let decision = wipDecision(
            destinationColumn: destinationColumn,
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
              let card = columns[sourceColumnIndex].cards.first(where: { $0.id == move.cardID }),
              let destinationColumnIndex = columns.firstIndex(where: { $0.id == move.destinationColumnID })
        else { return }

        withAnimation(theme.dropAnimation) {
            columns[sourceColumnIndex].cards.removeAll { $0.id == move.cardID }
            let clampedIndex = min(max(move.destinationIndex, 0), columns[destinationColumnIndex].cards.count)
            columns[destinationColumnIndex].cards.insert(card, at: clampedIndex)
        }
    }
}
