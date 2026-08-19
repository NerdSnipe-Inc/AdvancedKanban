# AdvancedKanban

A Kanban board component for SwiftUI on iOS, iPadOS, and macOS. You bring
your own model types and your own card UI; AdvancedKanban brings the board
mechanics — cross-column pointer drag with autoscroll, a full keyboard
move-mode, VoiceOver parity for every drag interaction, WIP limits, column
collapse, and a small theming surface — so you don't have to reimplement
drag-and-drop reordering from scratch for the third time.

There's no wrapper type to adopt and no separate "board model" to keep in
sync with your data. You conform your existing card and column types to two
small protocols, hand the board a `Binding<[Column]>`, and it drives
reordering directly on your array.

## Add a board in 3 steps

**1. Conform your card type to `KanbanCard`** — it only needs `Identifiable`
and `Equatable`:

```swift
import AdvancedKanban

struct ExampleTask: KanbanCard {
    let id: UUID
    var title: String
}
```

**2. Conform your column type to `KanbanColumn`** — it owns an ordered
`cards` array (order *is* the board's display order, no separate sort index
needed), an optional `wipLimit`, and an `isCollapsed` flag the board toggles
on tap:

```swift
struct Stage: KanbanColumn {
    let id: UUID
    var name: String
    var cards: [ExampleTask] = []
    var wipLimit: Int? = nil
    var isCollapsed: Bool = false
}
```

**3. Call `KanbanBoard`** with a binding to your columns and view builders
for card and column-header content:

```swift
import SwiftUI
import AdvancedKanban

struct ContentView: View {
    @State private var columns: [Stage] = [
        Stage(id: UUID(), name: "To Do", cards: [ExampleTask(id: UUID(), title: "Write README")]),
        Stage(id: UUID(), name: "In Progress", wipLimit: 3),
        Stage(id: UUID(), name: "Done"),
    ]

    var body: some View {
        KanbanBoard(
            columns: $columns,
            wipLimitBehavior: .preventDrop,
            onMove: { move in
                // move.cardID / .sourceColumnID / .destinationColumnID / .destinationIndex
                // — persist however you like (SwiftData, a network call, analytics).
            },
            // Optional: gives VoiceOver real column names ("Move to In
            // Progress") instead of describing the column by its raw id.
            columnTitle: { $0.name },
            cardContent: { task in
                Text(task.title).padding(8)
            },
            columnHeader: { stage in
                Text(stage.name).font(.headline)
            }
        )
    }
}
```

That's a complete, draggable, keyboard- and VoiceOver-accessible board. The
`onMove` closure fires *after* the board has already mutated your `columns`
binding, so it's purely a hook for persistence — you never diff arrays
yourself.

## Features

- **Cross-column drag and drop** — pointer-driven reorder within and across
  columns, with edge autoscroll when dragging near the board's horizontal
  edges.
- **Keyboard move-mode** — Tab to focus a card, Space to enter move mode,
  arrow keys to move within or across columns, Return to commit, Escape to
  cancel and restore the card's original position. No mouse required.
- **Native pointer support on macOS** — cards respond to hover with a
  theme-agnostic highlight (visible in light and dark themes alike) and a
  grab/grabbing cursor (macOS 15+, gracefully absent on 14), and the drag
  gesture's activation threshold is tuned per platform — tight for a
  precise pointer (mouse/trackpad), the standard looser threshold for
  touch. The board is built to be embedded in real, native Mac apps, not
  just tolerated on one.
- **VoiceOver parity** — every drag interaction has an equivalent
  accessibility action (Move Up / Move Down / Move to \<Column\>) exposed
  through the rotor, so VoiceOver users get the same reordering power as
  pointer and keyboard users.
- **WIP limits** — set `wipLimit` per column and choose `.warnOnly` (the
  column renders warning styling but the drop still succeeds) or
  `.preventDrop` (the drop is rejected and the card animates back) via
  `wipLimitBehavior`.
- **Column collapse** — columns collapse to a narrow title+count strip on
  tap; state lives on your own `isCollapsed` property, so it's easy to
  persist.
- **Theming** — `KanbanTheme` covers chrome-level tokens (backgrounds,
  borders, corner radii, spacing, WIP warning color, drag ghost opacity,
  drop animation) and is applied with `.kanbanTheme(_:)`. Card and
  column-header *content* is entirely yours via the `cardContent` and
  `columnHeader` view builders, so the theme never needs to know about your
  typography or layout.
- **Optional SwiftData adapter** — `AdvancedKanbanSwiftData` (a separate
  product) provides `SwiftDataKanbanCard` / `SwiftDataKanbanColumn` models
  and a `KanbanStore` that applies a `KanbanMove` to a `ModelContext` in one
  call. Not linked into the base `AdvancedKanban` library, so you're never
  forced into SwiftData if you don't want it.

## Theming example

```swift
// The `KanbanBoard(...)` call is abbreviated here — see the full,
// copy-pasteable version in "Add a board in 3 steps" above. Only the
// `.kanbanTheme(_:)` modifier is the point of this snippet.
KanbanBoard(
    columns: $columns,
    cardContent: { task in Text(task.title).padding(8) },
    columnHeader: { stage in Text(stage.name).font(.headline) }
)
    .kanbanTheme(
        KanbanTheme(
            columnBackground: .gray.opacity(0.08),
            cardBackground: .white,
            cardBorder: .gray.opacity(0.2),
            cardCornerRadius: 12,
            cardSpacing: 8,
            columnWidth: 280,
            columnCornerRadius: 16,
            wipLimitWarningColor: .orange,
            dragGhostOpacity: 0.85,
            dropAnimation: .spring(response: 0.35, dampingFraction: 0.8)
        )
    )
```

`KanbanTheme.default` is used automatically if you don't apply one.

## Example app

A runnable example lives in [`Example/`](Example/README.md). It demonstrates
cross-column drag with a WIP limit, custom card content, theme switching,
column collapse, keyboard reorder, and VoiceOver reorder — open
`Example/AdvancedKanbanExample.xcodeproj` in Xcode and run it on macOS or an
iOS/iPadOS simulator. Every view in the example also ships a `#Preview`, so
you can inspect each theme/state combination directly in Xcode's canvas
without running the app.

Two Xcode schemes are checked into the project — `AdvancedKanbanExample
(macOS)` and `AdvancedKanbanExample (iOS)` — so opening the project gives a
predictable, resizable native window on whichever platform you pick, rather
than leaving Xcode to auto-select one.

## Design spec

The full design rationale — protocol boundaries, drag-gesture state
machine, keyboard/VoiceOver parity model, WIP limit semantics, and theming
surface — is documented in
[`docs/superpowers/specs/2026-08-19-advanced-kanban-design.md`](docs/superpowers/specs/2026-08-19-advanced-kanban-design.md).

## Installation

Swift Package Manager, via Xcode (File > Add Package Dependencies) or
`Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/NerdSnipe-Inc/AdvancedKanban.git", from: "1.0.0")
]
```

Then add the product(s) you need to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "AdvancedKanban", package: "AdvancedKanban"),
        // Optional, only if you want the SwiftData persistence adapter:
        .product(name: "AdvancedKanbanSwiftData", package: "AdvancedKanban"),
    ]
)
```

Requires iOS 17+ / macOS 14+ and Swift 5.9+.

## License

AdvancedKanban is available under the MIT license. See [LICENSE](LICENSE)
for the full text.
