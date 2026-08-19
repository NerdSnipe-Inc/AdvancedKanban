# AdvancedKanban — Design Spec

Date: 2026-08-19
Status: Approved for planning

## 1. Summary

AdvancedKanban is an open-source Swift package that makes adding a full-featured,
premium-quality Kanban board to any SwiftUI app (iOS, iPadOS, macOS) as close to
"drop it in" as a highly customizable drag-and-drop UI component can be. It owns
board layout, drag/reorder interaction (pointer, keyboard, VoiceOver), WIP limits,
column collapse, and chrome theming. It does not own the consumer's data model or
persistence — it operates generically over the consumer's own card/column types via
lightweight protocols, and emits move events for the consumer to persist however
they choose. An optional companion module offers a ready-made SwiftData adapter for
consumers who want persistence out of the box.

## 2. Goals

- Adding a Kanban board to an existing SwiftUI app should require: conforming two
  existing types to two protocols, and writing a `KanbanBoard(...)` call — no
  data duplication, no adapter/mapping layer.
- Interaction quality matches or exceeds a native `List` — smooth drag, no flicker,
  edge autoscroll — but also **works identically as a keyboard reorder and as a
  VoiceOver-navigable reorder**, not just pointer drag. Most existing SwiftUI
  Kanban implementations are drag-only; this is the differentiator.
- Visual customization is real, not decorative: theme tokens for board/column/card
  chrome, full `@ViewBuilder` control over what's inside a card and a column header.
- Ship as a genuinely reusable public API: versioned, documented, an example app
  that demonstrates every feature, MIT-licensed.

## 3. Non-goals (v1)

- Swimlanes (horizontal grouping across columns).
- Multi-select drag (dragging a batch of cards at once).
- Package-owned persistence as the *only* path — persistence is opt-in via the
  separate `AdvancedKanbanSwiftData` product; the core package never requires it.
- Cross-app drag and drop (`Transferable`/pasteboard interop) — explicitly deferred;
  see §9.

## 4. Platform & toolchain baseline

- iOS 17+, iPadOS 17+, macOS 14+.
- Swift 5.9+ / Swift 6 language mode ready (strict concurrency clean).
- Pure SwiftUI. No UIKit/AppKit dependency in the core module.

## 5. Package structure

```
AdvancedKanban/
  Package.swift
  Sources/
    AdvancedKanban/
      Protocols/          KanbanCard, KanbanColumn
      Model/               KanbanMove, WIPLimitBehavior, KanbanTheme
      Engine/              KanbanDragEngine, KanbanFrameTracking (pure logic, no View)
      Views/               KanbanBoard, KanbanColumnView, KanbanCardView, DragGhostOverlay
      Accessibility/        accessibility action + keyboard move-mode modifiers
      Environment/          EnvironmentValues+kanbanTheme
    AdvancedKanbanSwiftData/
      SwiftDataKanbanCard.swift, SwiftDataKanbanColumn.swift, KanbanStore.swift
  Tests/
    AdvancedKanbanTests/
      KanbanDragEngineTests.swift
      WIPLimitTests.swift
      AccessibilityActionTests.swift
  Example/
    AdvancedKanbanExample.xcodeproj/
    AdvancedKanbanExample/    SwiftUI app target, local package dependency on "../"
  docs/
  README.md
  LICENSE (MIT)
  CONTRIBUTING.md
```

Two SPM library products from one `Package.swift`:
- `AdvancedKanban` — the core, zero third-party dependencies.
- `AdvancedKanbanSwiftData` — depends on `AdvancedKanban` + SwiftData; consumers who
  don't want it never link it.

## 6. Public data model

```swift
public protocol KanbanCard: Identifiable, Equatable {}

public protocol KanbanColumn: Identifiable {
    associatedtype Card: KanbanCard
    var cards: [Card] { get set }
    var wipLimit: Int? { get }
    var isCollapsed: Bool { get set }
}
```

- Consumers conform their existing model types directly — no wrapper types, no
  duplicated storage.
- `KanbanColumn.cards` is a plain array; ordering *is* the array order (no separate
  `position`/`sortIndex` field required, though consumers are free to derive one).
- `wipLimit` is read-only from the board's perspective (consumer-owned business
  rule); `isCollapsed` is read/write because the board toggles it directly via
  binding.

### Board view

```swift
public struct KanbanBoard<Column: KanbanColumn, CardContent: View, ColumnHeader: View>: View {
    public init(
        columns: Binding<[Column]>,
        wipLimitBehavior: WIPLimitBehavior = .warnOnly,
        onMove: ((KanbanMove<Column.Card.ID, Column.ID>) -> Void)? = nil,
        @ViewBuilder cardContent: @escaping (Column.Card) -> CardContent,
        @ViewBuilder columnHeader: @escaping (Column) -> ColumnHeader
    )
}
```

- `columns` binding is mutated directly and immediately (optimistic UI), mirroring
  `List` + `.onMove` semantics that Swift developers already know.
- `onMove` is a side-channel notification (not a gate) carrying a `KanbanMove`
  value: `cardID`, `sourceColumnID`, `sourceIndex`, `destinationColumnID`,
  `destinationIndex`. Consumers use it to persist (SwiftData save, network call,
  analytics) without needing to diff arrays themselves.
- `wipLimitBehavior`: `.warnOnly` (default — drop always succeeds, column shows
  warning styling) or `.preventDrop` (drop is rejected with snap-back animation
  when it would exceed the limit).

## 7. Drag engine

**Decision: hand-built on `DragGesture`, not `Transferable`/`.draggable()`/
`.dropDestination()`.** Rationale from research: `dropDestination(for:)` is
unreliable inside `List`/lazy containers on iOS, macOS has a known drag-preview
rendering bug, iOS has a `DropInfo.location` coordinate-space bug, and native DnD
gives no control over live insertion-point animation, WIP-limit-aware rejection,
or autoscroll — all of which this board requires. The credible SwiftUI reorder
prior art (`swiftui-reorderable-foreach`, `ReorderableView`) independently reached
the same conclusion.

### `KanbanDragEngine` (plain Swift, not a `View`)

Owns:
- **Frame tracking**: each card and each column's empty-drop-zone reports its frame
  in a named coordinate space (`"AdvancedKanban.board"`) via a `PreferenceKey`
  merged into a `[AnyHashable: CGRect]` map. Empty columns get an explicit
  min-height placeholder so they remain a valid drop target with zero cards.
- **Insertion-index resolution**: given a live pointer location, resolve
  (column, index) by comparing against each candidate card's **midpoint**, not its
  edge — this is the hysteresis fix for the flicker/jitter that naive
  edge-comparison implementations hit.
- **WIP-limit check**: pure function `(destinationColumn, behavior) -> DropDecision`.
- **Autoscroll**: edge-proximity band (top/bottom for column scroll, left/right for
  board scroll) drives a `Timer`-based incremental offset nudge while the pointer
  stays inside the band; cancels immediately on drag end or when the pointer
  leaves the band.
- **Move resolution**: `resolveMove(...) -> KanbanMove?` — the single function both
  the drag gesture handler and the keyboard move-mode call, so pointer and
  keyboard interaction can never drift out of sync with each other.

Because none of this touches `View`, `KanbanDragEngineTests` exercises index
resolution, hysteresis, WIP-limit decisions, and move resolution as plain unit
tests with no view hosting, snapshot testing, or UI test harness required.

### View layer

- `KanbanBoard` = horizontal `ScrollView` of `KanbanColumnView`s in a named
  coordinate space.
- `KanbanColumnView` = vertical `ScrollView` + `LazyVStack` of cards (lazy for
  scroll performance on large columns; plain `HStack` for the column row itself
  since column counts are typically small).
- Drag visuals: a floating ghost view following gesture translation via
  `.overlay` + `GestureState`-driven offset (not a system drag preview) — this is
  also what sidesteps the macOS native-drag-preview corruption bug entirely.
- `.simultaneousGesture` + a translation-direction lock (dominant axis wins) on
  the card's `DragGesture`, so it composes with the column `ScrollView`'s native
  scroll gesture instead of fighting it.

### Forward-looking note (not built in v1)

SwiftUI's upcoming OS-27 cycle introduces `.reorderable(collectionID:)` +
`.reorderContainer(for:in:move:)` — a native cross-container reorder API. Because
`KanbanDragEngine` is fully decoupled from the view layer behind `KanbanBoard`'s
public API, a `#available(iOS 27, macOS 27, *)`-gated native fast path can be
added later as a pure implementation swap with no public API break. Not part of
v1 scope; noted here so the architecture doesn't accidentally foreclose it.

## 8. Interaction parity: pointer, keyboard, VoiceOver

All three paths call `KanbanDragEngine.resolveMove(...)` — one source of truth for
what a "move" means, so behavior can't diverge between input methods.

- **Pointer/touch**: `DragGesture` as above. `.hoverEffect(.highlight)` on cards
  for iPad pointer/Mac Catalyst; `onHover` for cursor-based highlight on macOS.
- **Keyboard** (macOS pointer users, iPad with hardware keyboard): each card is
  `.focusable()`. `Space` or `Return` on a focused card enters "move mode"
  (visually distinct — theme-defined highlight ring); arrow keys shift the card's
  position, including across columns (left/right arrow when at a column boundary
  moves it into the adjacent column); `Return` commits, `Escape` cancels and
  restores original position. Implemented with `.onKeyPress` rather than
  synthesizing gesture events.
- **VoiceOver**: each card exposes `.accessibilityValue("\(index + 1) of \(count)
  in \(column.title)")` and custom `.accessibilityAction`s: "Move Up", "Move
  Down", and one "Move to <Column Name>" action per other column. All actions
  call `resolveMove` directly.

This directly targets the gap found in research: SwiftUI's native `List` edit-mode
reordering has no VoiceOver actions by default, and every existing SwiftUI Kanban
implementation found is pointer-drag-only.

## 9. Theming & customization

```swift
public struct KanbanTheme: Sendable {
    public var columnBackground: Color
    public var cardBackground: Color
    public var cardBorder: Color
    public var cardShadow: ShadowStyle
    public var cardCornerRadius: CGFloat
    public var cardSpacing: CGFloat
    public var columnWidth: CGFloat
    public var wipLimitWarningColor: Color
    public var dragGhostOpacity: Double
    public var dropAnimation: Animation
    public static let `default`: KanbanTheme
}
```

- Injected via `.kanbanTheme(_:)` view modifier, read internally and externally via
  `@Environment(\.kanbanTheme)`.
- The package renders column and card **chrome only** (background, border,
  shadow, padding, corner radius, drag/selection/WIP-warning state styling).
  Actual card content and column header content are consumer-supplied
  `@ViewBuilder`s — this is the `List`-row-content pattern, chosen specifically so
  a consumer with a structurally different card design (avatar + tags vs. a plain
  title) never fights a fixed schema, which was the most common structural
  complaint found in existing component libraries.
- Cross-app drag/drop (`Transferable` conformance for dragging a card out to
  Files/Mail/another app) is explicitly out of scope for v1 — it's an additive,
  independent capability that can be layered on later without touching the core
  reorder engine, so deferring it doesn't constrain anything above.

## 10. WIP limits & column collapse

- `wipLimit: Int?` on `KanbanColumn` — `nil` means unlimited.
- Column header renders `"\(cards.count)\(wipLimit.map { "/\($0)" } ?? "")"`;
  exceeding the limit switches header/border styling to
  `theme.wipLimitWarningColor`.
- `WIPLimitBehavior.warnOnly` (default) never blocks a drop. `.preventDrop`
  rejects a drop that would exceed the limit — the drag engine's `DropDecision`
  is `.reject`, the card animates back to its origin with `theme.dropAnimation`.
- `isCollapsed: Bool` on `KanbanColumn` — collapsed columns render as a narrow
  vertical strip (title + count only); tapping expands. Because it's on the
  consumer's own column type, collapse state naturally persists with whatever
  they already do for the rest of their model — no separate UI-state store needed.

## 11. Optional persistence adapter — `AdvancedKanbanSwiftData`

- Ships `@Model` types (`SwiftDataKanbanCard`, `SwiftDataKanbanColumn`) that
  already conform to `KanbanCard`/`KanbanColumn`, plus a small `KanbanStore`
  wrapping a `ModelContext` that applies a `KanbanMove` (reorder within
  `ModelContext`, save).
- Entirely optional: importing only `AdvancedKanban` never pulls in SwiftData.
  Consumers with their own persistence (Core Data, CloudKit, a backend) use the
  core package's protocols directly against their own types and ignore this
  module.

## 12. Example app

A SwiftUI app at `Example/AdvancedKanbanExample.xcodeproj`, multiplatform
(iOS/iPadOS + macOS), with a local Swift Package dependency on `../` (not a
remote reference — always builds against the in-repo source). Demonstrates:

- A realistic task-board domain model (`Task` with title, assignee avatar,
  priority tag, due date) conforming to `KanbanCard`; columns conforming to
  `KanbanColumn` with WIP limits set on two columns.
- Custom card content (`@ViewBuilder`) showing avatar + priority chip — proving
  the chrome/content split works for a non-trivial card design.
- A theme picker (light/dark + one custom high-contrast theme) to demonstrate
  `.kanbanTheme(_:)`.
- Column collapse and WIP-limit-exceeded states visibly exercised.
- Full keyboard reorder and VoiceOver walkthrough (documented in the example
  app's README, verified manually as part of implementation).
- The `AdvancedKanbanSwiftData` adapter wired up as the persistence layer, so the
  example is a complete, runnable reference implementation end to end.

## 13. Testing strategy

- **Unit tests** (`AdvancedKanbanTests`, Swift Testing): `KanbanDragEngine` index
  resolution and hysteresis, WIP-limit decision logic, `resolveMove`
  correctness for same-column and cross-column moves, edge cases (empty column,
  single-card column, move to same position).
- **Accessibility**: manual VoiceOver + keyboard verification against the example
  app (automated custom-action existence checks where practical) — this is a
  correctness-critical path per §8, not a nice-to-have.
- **No snapshot/UI testing dependency** required for v1 — the engine/view split
  keeps the hard-to-test surface (raw gesture handling) thin and the testable
  surface (move resolution, WIP logic) pure.

## 14. Versioning & licensing

- MIT license.
- Semantic versioning from `1.0.0`; the public API surface is everything listed
  in §6–§10 plus `AdvancedKanbanSwiftData`'s public types — anything else
  (`Engine/` internals) is `internal` and not covered by SemVer guarantees.

## 15. Open risks / watch items

- Autoscroll timer + `GestureState` interaction needs care to avoid retain
  cycles / timer leaks on drag cancellation — flagged for explicit test coverage
  during implementation, not just manual QA.
- Keyboard move-mode crossing column boundaries needs a clear focus-management
  story (where does focus land after `Return` commits) — to be nailed down
  during implementation with the accessibility skill/auditor.
- `ShadowStyle`/`Animation` are not `Equatable`, which affects how `KanbanTheme`
  can be compared/tested — plan to test theme *effects* (rendered values) rather
  than theme equality.
