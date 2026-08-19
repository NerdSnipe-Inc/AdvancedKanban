import SwiftUI

/// Chrome-level styling tokens for `KanbanBoard`. The package renders
/// column/card chrome only; actual card and column-header content are
/// consumer-supplied `@ViewBuilder`s, so this theme never needs to know
/// about content-level typography.
public struct KanbanTheme: Sendable {
    public var columnBackground: Color
    public var cardBackground: Color
    public var cardBorder: Color
    public var cardCornerRadius: CGFloat
    public var cardSpacing: CGFloat
    public var columnWidth: CGFloat
    public var columnCornerRadius: CGFloat
    public var wipLimitWarningColor: Color
    public var dragGhostOpacity: Double
    public var dropAnimation: Animation

    public init(
        columnBackground: Color,
        cardBackground: Color,
        cardBorder: Color,
        cardCornerRadius: CGFloat,
        cardSpacing: CGFloat,
        columnWidth: CGFloat,
        columnCornerRadius: CGFloat,
        wipLimitWarningColor: Color,
        dragGhostOpacity: Double,
        dropAnimation: Animation
    ) {
        self.columnBackground = columnBackground
        self.cardBackground = cardBackground
        self.cardBorder = cardBorder
        self.cardCornerRadius = cardCornerRadius
        self.cardSpacing = cardSpacing
        self.columnWidth = columnWidth
        self.columnCornerRadius = columnCornerRadius
        self.wipLimitWarningColor = wipLimitWarningColor
        self.dragGhostOpacity = dragGhostOpacity
        self.dropAnimation = dropAnimation
    }

    public static let `default` = KanbanTheme(
        columnBackground: .secondarySystemBackgroundCompat,
        cardBackground: .systemBackgroundCompat,
        cardBorder: Color.gray.opacity(0.25),
        cardCornerRadius: 10,
        cardSpacing: 8,
        columnWidth: 280,
        columnCornerRadius: 14,
        wipLimitWarningColor: .orange,
        dragGhostOpacity: 0.85,
        dropAnimation: .spring(response: 0.35, dampingFraction: 0.8)
    )
}

extension Color {
    /// `UIColor.secondarySystemBackground`/`.systemBackground` don't exist
    /// on macOS; this normalizes to `Color` values that look right on both
    /// platforms without `#if os` littering `KanbanTheme.default`.
    fileprivate static var secondarySystemBackgroundCompat: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(nsColor: .underPageBackgroundColor)
        #endif
    }

    fileprivate static var systemBackgroundCompat: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .textBackgroundColor)
        #endif
    }
}
