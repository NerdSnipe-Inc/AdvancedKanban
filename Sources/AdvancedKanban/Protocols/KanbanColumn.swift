/// A column on a Kanban board, owning an ordered list of cards.
///
/// Conform your existing model type directly. `cards` order *is* the
/// board's card order — no separate position/sortIndex field is required.
public protocol KanbanColumn: Identifiable {
    associatedtype Card: KanbanCard

    /// The cards in this column, in display order.
    var cards: [Card] { get set }

    /// Maximum number of cards this column should hold, or `nil` for
    /// unlimited. Read-only from the board's perspective — this is a
    /// consumer-owned business rule.
    var wipLimit: Int? { get }

    /// Whether the column is rendered collapsed (a narrow title+count
    /// strip) or expanded. Read/write because the board toggles it
    /// directly on tap.
    var isCollapsed: Bool { get set }
}
