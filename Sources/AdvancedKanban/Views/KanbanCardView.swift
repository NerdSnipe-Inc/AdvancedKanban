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
struct KanbanCardView<Card: KanbanCard, Content: View>: View {
    @Environment(\.kanbanTheme) private var theme
    @State private var isHovering = false

    let card: Card
    let columnID: AnyHashable
    let isBeingDragged: Bool
    let isOverWIPWarning: Bool
    @ViewBuilder let content: (Card) -> Content

    init(
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

    var body: some View {
        chrome
            .onHover { hovering in
                isHovering = hovering
            }
            #if os(iOS)
            // iPadOS pointer users get the system-native highlight treatment.
            .hoverEffect(.highlight)
            #endif
            .withGrabCursor(isHovering: isHovering, isDragging: isBeingDragged)
    }

    private var chrome: some View {
        content(card)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .strokeBorder(
                        isOverWIPWarning ? theme.wipLimitWarningColor : theme.cardBorder,
                        lineWidth: isOverWIPWarning ? 2 : (isHovering && !isBeingDragged ? 1.5 : 1)
                    )
            )
            // Cross-platform "lift" affordance for pointer/trackpad users
            // (mouse on macOS, trackpad-connected iPad) — touch input never
            // triggers onHover, so this is purely additive there.
            //
            // Brightness is the primary cue: it's visible against any
            // theme's card background, light or dark. The border-width bump
            // above is the second, theme-agnostic cue. The shadow is a
            // light-mode-oriented flourish on top — a black shadow reads
            // clearly against a light card but all but disappears against a
            // dark one, so it must never be the *only* affordance.
            .brightness(isHovering && !isBeingDragged ? 0.04 : 0)
            .scaleEffect(isHovering && !isBeingDragged ? 1.02 : 1)
            .shadow(
                color: .black.opacity(isHovering && !isBeingDragged ? 0.15 : 0),
                radius: isHovering && !isBeingDragged ? 6 : 0,
                y: isHovering && !isBeingDragged ? 2 : 0
            )
            .animation(.easeOut(duration: 0.12), value: isHovering)
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

private extension View {
    /// Shows an open-hand cursor on hover and a closed-hand cursor while
    /// actively dragging, on macOS 15+. `PointerStyle` doesn't exist prior
    /// to macOS 15 — gated as a progressive enhancement rather than raising
    /// the package's platform floor for a cursor affordance alone.
    @ViewBuilder
    func withGrabCursor(isHovering: Bool, isDragging: Bool) -> some View {
        #if os(macOS)
        if #available(macOS 15, *) {
            pointerStyle(isDragging ? .grabActive : (isHovering ? .grabIdle : nil))
        } else {
            self
        }
        #else
        self
        #endif
    }
}
