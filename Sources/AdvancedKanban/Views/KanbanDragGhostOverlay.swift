import SwiftUI

/// A floating copy of the dragged card's content, positioned at the
/// gesture's live translation. Rendered as a plain overlay (not a system
/// drag preview), which is also what avoids the macOS native-drag-preview
/// rendering bug noted in the design spec.
public struct KanbanDragGhostOverlay<Content: View>: View {
    @Environment(\.kanbanTheme) private var theme

    let content: Content
    let position: CGPoint
    let size: CGSize

    public init(content: Content, position: CGPoint, size: CGSize) {
        self.content = content
        self.position = position
        self.size = size
    }

    public var body: some View {
        content
            .padding(12)
            .frame(width: size.width, height: size.height, alignment: .leading)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            .shadow(radius: 8, y: 4)
            .opacity(theme.dragGhostOpacity)
            .position(position)
            .allowsHitTesting(false)
            .animation(nil, value: position) // ghost tracks the finger 1:1, no lag
    }
}
