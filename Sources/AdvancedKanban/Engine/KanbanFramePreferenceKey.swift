import CoreGraphics
import SwiftUI

/// One card's or one column's reported frame in the board's named
/// coordinate space (`KanbanCoordinateSpace.name`).
///
/// IDs are type-erased to `AnyHashable` here deliberately: `KanbanCardView`
/// only knows its `Card` type, not the enclosing `Column` type's ID, so it
/// cannot parameterize a generic preference key with `Column.ID`. Every
/// reporter (`KanbanCardView`, `KanbanColumnView`) and the single listener
/// (`KanbanBoard`) must therefore share this exact non-generic type —
/// SwiftUI merges preference values by `PreferenceKey` type, so two
/// differently-parameterized generic instantiations would silently never
/// merge. `KanbanBoard`, which knows the concrete `Column`/`Card` types,
/// casts `AnyHashable.base` back to the concrete ID types when it consumes
/// this (see Task 11).
public enum KanbanFrame: Equatable {
    case card(AnyHashable, CGRect)
    case columnZone(AnyHashable, CGRect)
}

/// Merges every card's and column's frame report up to `KanbanBoard`,
/// which uses them to drive `KanbanDragState.updatePointer`.
public struct KanbanFramePreferenceKey: PreferenceKey {
    public static var defaultValue: [KanbanFrame] { [] }

    public static func reduce(
        value: inout [KanbanFrame],
        nextValue: () -> [KanbanFrame]
    ) {
        value.append(contentsOf: nextValue())
    }
}
