# AdvancedKanban Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build AdvancedKanban, an open-source Swift package that adds a premium, fully customizable, accessibility-complete Kanban board to any SwiftUI app on iOS/iPadOS/macOS, plus an optional SwiftData persistence adapter and a runnable example app.

**Architecture:** A pure-Swift, view-independent drag/reorder engine (geometry resolution, WIP-limit decisions, move resolution, autoscroll math — all unit-testable with no view hosting) drives a thin SwiftUI view layer (`KanbanBoard` → `KanbanColumnView` → `KanbanCardView`) built on hand-rolled `DragGesture` + coordinate-space hit-testing (not `Transferable`/`.draggable()`, per the spec's research findings). The board operates generically over consumer types via `KanbanCard`/`KanbanColumn` protocols and a `Binding<[Column]>`, mirroring `List` + `.onMove` semantics.

**Tech Stack:** Swift 5.9+ (Swift 6 language mode ready), SwiftUI, Swift Testing (`import Testing`), SwiftData (optional adapter target only), XcodeGen (for the example app's `.xcodeproj`).

**Spec:** `docs/superpowers/specs/2026-08-19-advanced-kanban-design.md`

## Global Constraints

- Platform floor: iOS 17+, iPadOS 17+, macOS 14+ (from spec §4).
- Pure SwiftUI in the core module — no UIKit/AppKit dependency (spec §4).
- Core `AdvancedKanban` product has zero third-party dependencies; `AdvancedKanbanSwiftData` is a separate product so importing the core never pulls in SwiftData (spec §5, §11).
- Drag engine logic (`Engine/`) must be plain Swift — no `View` conformance — so it is unit-testable without hosting a view hierarchy (spec §7).
- Pointer, keyboard, and VoiceOver interaction must all route through the same move-resolution function — no divergent logic per input method (spec §8).
- Package renders column/card chrome only; card content and column header content are consumer-supplied `@ViewBuilder`s (spec §9).
- MIT license, SemVer from `1.0.0` (spec §14).

---

## Task 1: Package scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/AdvancedKanban/AdvancedKanban.swift` (empty marker file with module doc comment)
- Create: `Sources/AdvancedKanbanSwiftData/AdvancedKanbanSwiftData.swift` (empty marker file with module doc comment)
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `README.md` (stub — filled in fully in Task 16)

**Interfaces:**
- Produces: the `AdvancedKanban` and `AdvancedKanbanSwiftData` SPM targets/products that every later task adds files to.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AdvancedKanban",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AdvancedKanban", targets: ["AdvancedKanban"]),
        .library(name: "AdvancedKanbanSwiftData", targets: ["AdvancedKanbanSwiftData"]),
    ],
    targets: [
        .target(name: "AdvancedKanban"),
        .target(
            name: "AdvancedKanbanSwiftData",
            dependencies: ["AdvancedKanban"]
        ),
        .testTarget(
            name: "AdvancedKanbanTests",
            dependencies: ["AdvancedKanban"]
        ),
    ]
)
```

- [ ] **Step 2: Create module marker files**

`Sources/AdvancedKanban/AdvancedKanban.swift`:
```swift
// AdvancedKanban — a premium, fully customizable Kanban board component for SwiftUI.
// See docs/superpowers/specs/2026-08-19-advanced-kanban-design.md for the design.
```

`Sources/AdvancedKanbanSwiftData/AdvancedKanbanSwiftData.swift`:
```swift
// AdvancedKanbanSwiftData — optional SwiftData persistence adapter for AdvancedKanban.
```

- [ ] **Step 3: Write `.gitignore`**

```
.DS_Store
.build/
.swiftpm/
xcuserdata/
DerivedData/
*.xcodeproj/project.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
```

- [ ] **Step 4: Write `LICENSE`**

Standard MIT license text, copyright line `Copyright (c) 2026 NerdSnipe Inc`.

- [ ] **Step 5: Write `README.md` stub**

```markdown
# AdvancedKanban

A premium, fully customizable Kanban board for SwiftUI on iOS, iPadOS, and macOS.

> Documentation in progress — see `docs/superpowers/specs/2026-08-19-advanced-kanban-design.md` for the design.
```

- [ ] **Step 6: Verify the package builds**

Run: `swift build`
Expected: Build succeeds with no targets doing anything yet (empty modules compile fine).

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources .gitignore LICENSE README.md
git commit -m "Scaffold AdvancedKanban SPM package"
```

---

## Task 2: Core protocols and move/WIP model types

**Files:**
- Create: `Sources/AdvancedKanban/Protocols/KanbanCard.swift`
- Create: `Sources/AdvancedKanban/Protocols/KanbanColumn.swift`
- Create: `Sources/AdvancedKanban/Model/KanbanMove.swift`
- Create: `Sources/AdvancedKanban/Model/WIPLimitBehavior.swift`
- Test: `Tests/AdvancedKanbanTests/KanbanMoveTests.swift`

**Interfaces:**
- Produces: `KanbanCard` protocol, `KanbanColumn` protocol (`associatedtype Card: KanbanCard`, `cards: [Card]`, `wipLimit: Int?`, `isCollapsed: Bool`), `KanbanMove<CardID: Hashable, ColumnID: Hashable>` struct with fields `cardID`, `sourceColumnID`, `sourceIndex`, `destinationColumnID`, `destinationIndex`, `WIPLimitBehavior` enum (`.warnOnly`, `.preventDrop`).

- [ ] **Step 1: Write the failing test for `KanbanMove` equality**

`Tests/AdvancedKanbanTests/KanbanMoveTests.swift`:
```swift
import Testing
@testable import AdvancedKanban

@Suite struct KanbanMoveTests {
    @Test func movesWithIdenticalFieldsAreEqual() {
        let a = KanbanMove(cardID: "card-1", sourceColumnID: "todo", sourceIndex: 0, destinationColumnID: "doing", destinationIndex: 1)
        let b = KanbanMove(cardID: "card-1", sourceColumnID: "todo", sourceIndex: 0, destinationColumnID: "doing", destinationIndex: 1)
        #expect(a == b)
    }

    @Test func movesWithDifferentDestinationsAreNotEqual() {
        let a = KanbanMove(cardID: "card-1", sourceColumnID: "todo", sourceIndex: 0, destinationColumnID: "doing", destinationIndex: 1)
        let b = KanbanMove(cardID: "card-1", sourceColumnID: "todo", sourceIndex: 0, destinationColumnID: "doing", destinationIndex: 2)
        #expect(a != b)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KanbanMoveTests`
Expected: FAIL — `KanbanMove` does not exist yet (compile error).

- [ ] **Step 3: Write `KanbanCard` and `KanbanColumn` protocols**

`Sources/AdvancedKanban/Protocols/KanbanCard.swift`:
```swift
/// A single draggable item on a Kanban board.
///
/// Conform your existing model type directly — no wrapper type or data
/// duplication is required.
public protocol KanbanCard: Identifiable, Equatable {}
```

`Sources/AdvancedKanban/Protocols/KanbanColumn.swift`:
```swift
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
```

- [ ] **Step 4: Write `KanbanMove` and `WIPLimitBehavior`**

`Sources/AdvancedKanban/Model/KanbanMove.swift`:
```swift
/// Describes a single card move, emitted by `KanbanBoard` via `onMove`
/// after the board's local `columns` binding has already been mutated.
///
/// Consumers use this to persist the change (SwiftData save, network
/// call, analytics) without needing to diff arrays themselves.
public struct KanbanMove<CardID: Hashable, ColumnID: Hashable>: Equatable {
    public let cardID: CardID
    public let sourceColumnID: ColumnID
    public let sourceIndex: Int
    public let destinationColumnID: ColumnID
    public let destinationIndex: Int

    public init(
        cardID: CardID,
        sourceColumnID: ColumnID,
        sourceIndex: Int,
        destinationColumnID: ColumnID,
        destinationIndex: Int
    ) {
        self.cardID = cardID
        self.sourceColumnID = sourceColumnID
        self.sourceIndex = sourceIndex
        self.destinationColumnID = destinationColumnID
        self.destinationIndex = destinationIndex
    }
}
```

`Sources/AdvancedKanban/Model/WIPLimitBehavior.swift`:
```swift
/// Controls what happens when a drop would put a column over its
/// `wipLimit`.
public enum WIPLimitBehavior: Sendable, Equatable {
    /// The drop always succeeds; the column renders warning styling while
    /// over limit. Default.
    case warnOnly

    /// A drop that would exceed the limit is rejected; the dragged card
    /// animates back to its origin.
    case preventDrop
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter KanbanMoveTests`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/AdvancedKanban/Protocols Sources/AdvancedKanban/Model Tests/AdvancedKanbanTests/KanbanMoveTests.swift
git commit -m "Add KanbanCard/KanbanColumn protocols, KanbanMove, WIPLimitBehavior"
```

---

## Task 3: Geometry types and insertion-point resolver

**Files:**
- Create: `Sources/AdvancedKanban/Engine/KanbanGeometry.swift`
- Create: `Sources/AdvancedKanban/Engine/KanbanInsertionResolver.swift`
- Test: `Tests/AdvancedKanbanTests/KanbanInsertionResolverTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks besides Swift/Foundation/CoreGraphics.
- Produces: `KanbanCardFrame<CardID: Hashable>` (`cardID`, `frame: CGRect`), `KanbanColumnZone<ColumnID: Hashable>` (`columnID`, `frame: CGRect`), `KanbanInsertionResolver.resolve(pointerLocation:cardFrames:columnZones:cardColumns:cardOrder:) -> (columnID: ColumnID, index: Int)?`.

- [ ] **Step 1: Write the failing tests**

`Tests/AdvancedKanbanTests/KanbanInsertionResolverTests.swift`:
```swift
import Testing
import CoreGraphics
@testable import AdvancedKanban

@Suite struct KanbanInsertionResolverTests {
    // Column "todo" has two cards stacked vertically: "a" at y 0-50, "b" at y 50-100.
    // Column "doing" is empty, occupying x 200-400, y 0-100.
    private func fixture() -> (
        cardFrames: [KanbanCardFrame<String>],
        columnZones: [KanbanColumnZone<String>],
        cardColumns: [String: String],
        cardOrder: [String: [String]]
    ) {
        let cardFrames = [
            KanbanCardFrame(cardID: "a", frame: CGRect(x: 0, y: 0, width: 200, height: 50)),
            KanbanCardFrame(cardID: "b", frame: CGRect(x: 0, y: 50, width: 200, height: 50)),
        ]
        let columnZones = [
            KanbanColumnZone(columnID: "todo", frame: CGRect(x: 0, y: 0, width: 200, height: 100)),
            KanbanColumnZone(columnID: "doing", frame: CGRect(x: 200, y: 0, width: 200, height: 100)),
        ]
        let cardColumns = ["a": "todo", "b": "todo"]
        let cardOrder = ["todo": ["a", "b"], "doing": []]
        return (cardFrames, columnZones, cardColumns, cardOrder)
    }

    @Test func pointerAboveFirstCardMidpointResolvesToIndexZero() {
        let f = fixture()
        let result = KanbanInsertionResolver.resolve(
            pointerLocation: CGPoint(x: 100, y: 10),
            cardFrames: f.cardFrames, columnZones: f.columnZones,
            cardColumns: f.cardColumns, cardOrder: f.cardOrder
        )
        #expect(result?.columnID == "todo")
        #expect(result?.index == 0)
    }

    @Test func pointerBetweenCardMidpointsResolvesToIndexOne() {
        let f = fixture()
        // Card "a" midpoint is y=25, card "b" midpoint is y=75. y=60 is past
        // "a"'s midpoint but before "b"'s — should insert at index 1.
        let result = KanbanInsertionResolver.resolve(
            pointerLocation: CGPoint(x: 100, y: 60),
            cardFrames: f.cardFrames, columnZones: f.columnZones,
            cardColumns: f.cardColumns, cardOrder: f.cardOrder
        )
        #expect(result?.columnID == "todo")
        #expect(result?.index == 1)
    }

    @Test func pointerPastLastCardMidpointResolvesToEndIndex() {
        let f = fixture()
        let result = KanbanInsertionResolver.resolve(
            pointerLocation: CGPoint(x: 100, y: 90),
            cardFrames: f.cardFrames, columnZones: f.columnZones,
            cardColumns: f.cardColumns, cardOrder: f.cardOrder
        )
        #expect(result?.columnID == "todo")
        #expect(result?.index == 2)
    }

    @Test func pointerOverEmptyColumnResolvesToIndexZero() {
        let f = fixture()
        let result = KanbanInsertionResolver.resolve(
            pointerLocation: CGPoint(x: 300, y: 50),
            cardFrames: f.cardFrames, columnZones: f.columnZones,
            cardColumns: f.cardColumns, cardOrder: f.cardOrder
        )
        #expect(result?.columnID == "doing")
        #expect(result?.index == 0)
    }

    @Test func pointerOutsideAllZonesResolvesToNearestColumn() {
        let f = fixture()
        // x=500 is past every zone; nearest is "doing" (x 200-400).
        let result = KanbanInsertionResolver.resolve(
            pointerLocation: CGPoint(x: 500, y: 50),
            cardFrames: f.cardFrames, columnZones: f.columnZones,
            cardColumns: f.cardColumns, cardOrder: f.cardOrder
        )
        #expect(result?.columnID == "doing")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter KanbanInsertionResolverTests`
Expected: FAIL — `KanbanCardFrame`, `KanbanColumnZone`, `KanbanInsertionResolver` don't exist yet.

- [ ] **Step 3: Write `KanbanGeometry.swift`**

```swift
import CoreGraphics

/// A dragged-card-eligible card's on-screen frame, reported by
/// `KanbanCardView` via `KanbanFramePreferenceKey` in the board's named
/// coordinate space.
public struct KanbanCardFrame<CardID: Hashable>: Equatable {
    public let cardID: CardID
    public let frame: CGRect

    public init(cardID: CardID, frame: CGRect) {
        self.cardID = cardID
        self.frame = frame
    }
}

/// A column's drop-target frame (its full scrollable area, including when
/// the column has zero cards), reported the same way as `KanbanCardFrame`.
public struct KanbanColumnZone<ColumnID: Hashable>: Equatable {
    public let columnID: ColumnID
    public let frame: CGRect

    public init(columnID: ColumnID, frame: CGRect) {
        self.columnID = columnID
        self.frame = frame
    }
}
```

- [ ] **Step 4: Write `KanbanInsertionResolver.swift`**

```swift
import CoreGraphics

/// Resolves which column and index a dragged card should land at, given the
/// pointer's current location in the board's coordinate space.
public enum KanbanInsertionResolver {
    /// Uses each card's frame **midpoint** — not its edge — as the crossing
    /// threshold. Comparing against the edge causes the insertion index to
    /// flicker as the pointer hovers near a card boundary; the midpoint
    /// comparison is stable because the pointer has to cross half the card's
    /// height before the index changes.
    public static func resolve<CardID: Hashable, ColumnID: Hashable>(
        pointerLocation: CGPoint,
        cardFrames: [KanbanCardFrame<CardID>],
        columnZones: [KanbanColumnZone<ColumnID>],
        cardColumns: [CardID: ColumnID],
        cardOrder: [ColumnID: [CardID]]
    ) -> (columnID: ColumnID, index: Int)? {
        guard let targetColumn = columnZones.first(where: { $0.frame.contains(pointerLocation) })
            ?? nearestColumn(to: pointerLocation, in: columnZones)
        else {
            return nil
        }

        let orderedCardIDs = cardOrder[targetColumn.columnID] ?? []
        let framesInColumn = orderedCardIDs.compactMap { id in
            cardFrames.first(where: { $0.cardID == id })
        }

        var index = framesInColumn.count
        for (i, cardFrame) in framesInColumn.enumerated() {
            if pointerLocation.y < cardFrame.frame.midY {
                index = i
                break
            }
        }
        return (targetColumn.columnID, index)
    }

    private static func nearestColumn<ColumnID: Hashable>(
        to point: CGPoint,
        in zones: [KanbanColumnZone<ColumnID>]
    ) -> KanbanColumnZone<ColumnID>? {
        zones.min { distance(from: point, to: $0.frame) < distance(from: point, to: $1.frame) }
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter KanbanInsertionResolverTests`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/AdvancedKanban/Engine/KanbanGeometry.swift Sources/AdvancedKanban/Engine/KanbanInsertionResolver.swift Tests/AdvancedKanbanTests/KanbanInsertionResolverTests.swift
git commit -m "Add KanbanInsertionResolver with midpoint-hysteresis hit testing"
```

---

## Task 4: Move resolver

**Files:**
- Create: `Sources/AdvancedKanban/Engine/KanbanMoveResolver.swift`
- Test: `Tests/AdvancedKanbanTests/KanbanMoveResolverTests.swift`

**Interfaces:**
- Consumes: `KanbanMove<CardID, ColumnID>` (Task 2).
- Produces: `KanbanMoveResolver.resolve(cardID:sourceColumnID:sourceIndex:destinationColumnID:destinationIndex:) -> KanbanMove<CardID, ColumnID>?` — the single function both drag-gesture handling (Task 11) and keyboard move-mode (Task 13) call.

- [ ] **Step 1: Write the failing tests**

`Tests/AdvancedKanbanTests/KanbanMoveResolverTests.swift`:
```swift
import Testing
@testable import AdvancedKanban

@Suite struct KanbanMoveResolverTests {
    @Test func sameColumnSameIndexResolvesToNil() {
        let move = KanbanMoveResolver.resolve(
            cardID: "a", sourceColumnID: "todo", sourceIndex: 1,
            destinationColumnID: "todo", destinationIndex: 1
        )
        #expect(move == nil)
    }

    @Test func crossColumnMovePreservesDestinationIndex() {
        let move = KanbanMoveResolver.resolve(
            cardID: "a", sourceColumnID: "todo", sourceIndex: 0,
            destinationColumnID: "doing", destinationIndex: 2
        )
        #expect(move == KanbanMove(cardID: "a", sourceColumnID: "todo", sourceIndex: 0, destinationColumnID: "doing", destinationIndex: 2))
    }

    @Test func sameColumnForwardMoveDecrementsDestinationIndex() {
        // Moving card at index 0 to "index 2" in the same column: once
        // removed, everything shifts down by one, so the effective landing
        // index is 1, not 2.
        let move = KanbanMoveResolver.resolve(
            cardID: "a", sourceColumnID: "todo", sourceIndex: 0,
            destinationColumnID: "todo", destinationIndex: 2
        )
        #expect(move?.destinationIndex == 1)
    }

    @Test func sameColumnBackwardMoveKeepsDestinationIndex() {
        let move = KanbanMoveResolver.resolve(
            cardID: "a", sourceColumnID: "todo", sourceIndex: 2,
            destinationColumnID: "todo", destinationIndex: 0
        )
        #expect(move?.destinationIndex == 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter KanbanMoveResolverTests`
Expected: FAIL — `KanbanMoveResolver` doesn't exist yet.

- [ ] **Step 3: Write `KanbanMoveResolver.swift`**

```swift
/// Resolves a candidate (source, destination) pair into a `KanbanMove`,
/// or `nil` if the move is a no-op.
///
/// This is the single source of truth for "what does moving a card here
/// mean" — pointer drag, keyboard move-mode, and VoiceOver actions all call
/// this function so their behavior can never diverge.
public enum KanbanMoveResolver {
    public static func resolve<CardID: Hashable, ColumnID: Hashable>(
        cardID: CardID,
        sourceColumnID: ColumnID,
        sourceIndex: Int,
        destinationColumnID: ColumnID,
        destinationIndex: Int
    ) -> KanbanMove<CardID, ColumnID>? {
        if sourceColumnID == destinationColumnID && sourceIndex == destinationIndex {
            return nil
        }

        // Within the same column, removing the card at `sourceIndex` shifts
        // every later index down by one before insertion happens — so a
        // forward move's destination must be decremented to land where the
        // caller actually intended.
        var adjustedDestinationIndex = destinationIndex
        if sourceColumnID == destinationColumnID && destinationIndex > sourceIndex {
            adjustedDestinationIndex -= 1
        }

        return KanbanMove(
            cardID: cardID,
            sourceColumnID: sourceColumnID,
            sourceIndex: sourceIndex,
            destinationColumnID: destinationColumnID,
            destinationIndex: adjustedDestinationIndex
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter KanbanMoveResolverTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/AdvancedKanban/Engine/KanbanMoveResolver.swift Tests/AdvancedKanbanTests/KanbanMoveResolverTests.swift
git commit -m "Add KanbanMoveResolver as the single move-resolution source of truth"
```

---

## Task 5: WIP limit evaluator

**Files:**
- Create: `Sources/AdvancedKanban/Engine/WIPLimitEvaluator.swift`
- Test: `Tests/AdvancedKanbanTests/WIPLimitEvaluatorTests.swift`

**Interfaces:**
- Consumes: `WIPLimitBehavior` (Task 2).
- Produces: `WIPLimitDropDecision` enum (`.accept`, `.acceptWithWarning`, `.reject`), `WIPLimitEvaluator.evaluate(destinationCardCount:wipLimit:behavior:isMovingWithinSameColumn:) -> WIPLimitDropDecision`.

- [ ] **Step 1: Write the failing tests**

`Tests/AdvancedKanbanTests/WIPLimitEvaluatorTests.swift`:
```swift
import Testing
@testable import AdvancedKanban

@Suite struct WIPLimitEvaluatorTests {
    @Test func noLimitAlwaysAccepts() {
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: 100, wipLimit: nil,
            behavior: .preventDrop, isMovingWithinSameColumn: false
        )
        #expect(decision == .accept)
    }

    @Test func underLimitAccepts() {
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: 2, wipLimit: 5,
            behavior: .preventDrop, isMovingWithinSameColumn: false
        )
        #expect(decision == .accept)
    }

    @Test func crossColumnDropExceedingLimitWithWarnOnlyAcceptsWithWarning() {
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: 5, wipLimit: 5,
            behavior: .warnOnly, isMovingWithinSameColumn: false
        )
        #expect(decision == .acceptWithWarning)
    }

    @Test func crossColumnDropExceedingLimitWithPreventDropRejects() {
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: 5, wipLimit: 5,
            behavior: .preventDrop, isMovingWithinSameColumn: false
        )
        #expect(decision == .reject)
    }

    @Test func reorderWithinSameColumnDoesNotCountTheMovingCardTwice() {
        // The card being moved is already counted in destinationCardCount
        // when the move stays within the same column, so a column exactly
        // at its limit should not be treated as "over" for a same-column
        // reorder.
        let decision = WIPLimitEvaluator.evaluate(
            destinationCardCount: 5, wipLimit: 5,
            behavior: .preventDrop, isMovingWithinSameColumn: true
        )
        #expect(decision == .accept)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter WIPLimitEvaluatorTests`
Expected: FAIL — `WIPLimitDropDecision`/`WIPLimitEvaluator` don't exist yet.

- [ ] **Step 3: Write `WIPLimitEvaluator.swift`**

```swift
/// The outcome of checking a candidate drop against a column's WIP limit.
public enum WIPLimitDropDecision: Equatable {
    case accept
    case acceptWithWarning
    case reject
}

public enum WIPLimitEvaluator {
    /// - Parameters:
    ///   - destinationCardCount: The destination column's current card
    ///     count, *before* the move is applied.
    ///   - isMovingWithinSameColumn: `true` when source and destination
    ///     column are the same — the moving card is already included in
    ///     `destinationCardCount`, so it must not be counted again.
    public static func evaluate(
        destinationCardCount: Int,
        wipLimit: Int?,
        behavior: WIPLimitBehavior,
        isMovingWithinSameColumn: Bool
    ) -> WIPLimitDropDecision {
        guard let wipLimit else { return .accept }

        let effectiveCount = isMovingWithinSameColumn ? destinationCardCount : destinationCardCount + 1
        guard effectiveCount > wipLimit else { return .accept }

        switch behavior {
        case .warnOnly: return .acceptWithWarning
        case .preventDrop: return .reject
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter WIPLimitEvaluatorTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/AdvancedKanban/Engine/WIPLimitEvaluator.swift Tests/AdvancedKanbanTests/WIPLimitEvaluatorTests.swift
git commit -m "Add WIPLimitEvaluator drop-decision logic"
```

---

## Task 6: Autoscroll calculator

**Files:**
- Create: `Sources/AdvancedKanban/Engine/KanbanAutoscroll.swift`
- Test: `Tests/AdvancedKanbanTests/KanbanAutoscrollTests.swift`

**Interfaces:**
- Produces: `KanbanAutoscrollDirection` enum (`.none`, `.negative(magnitude: CGFloat)`, `.positive(magnitude: CGFloat)`), `KanbanAutoscrollCalculator.direction(pointerPosition:bounds:edgeBand:maxSpeed:) -> KanbanAutoscrollDirection`.

- [ ] **Step 1: Write the failing tests**

`Tests/AdvancedKanbanTests/KanbanAutoscrollTests.swift`:
```swift
import Testing
import CoreGraphics
@testable import AdvancedKanban

@Suite struct KanbanAutoscrollTests {
    @Test func pointerInTheMiddleProducesNoScroll() {
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: 500, bounds: 0...1000, edgeBand: 50, maxSpeed: 20
        )
        #expect(direction == .none)
    }

    @Test func pointerAtLowerEdgeProducesMaxNegativeSpeed() {
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: 0, bounds: 0...1000, edgeBand: 50, maxSpeed: 20
        )
        #expect(direction == .negative(magnitude: 20))
    }

    @Test func pointerAtUpperEdgeProducesMaxPositiveSpeed() {
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: 1000, bounds: 0...1000, edgeBand: 50, maxSpeed: 20
        )
        #expect(direction == .positive(magnitude: 20))
    }

    @Test func pointerHalfwayThroughLowerBandProducesHalfSpeed() {
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: 25, bounds: 0...1000, edgeBand: 50, maxSpeed: 20
        )
        #expect(direction == .negative(magnitude: 10))
    }

    @Test func pointerOutsideBoundsEntirelyProducesNoScroll() {
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: -50, bounds: 0...1000, edgeBand: 50, maxSpeed: 20
        )
        #expect(direction == .none)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter KanbanAutoscrollTests`
Expected: FAIL — types don't exist yet.

- [ ] **Step 3: Write `KanbanAutoscroll.swift`**

```swift
import CoreGraphics

/// Which way, and how fast, a scroll container should autoscroll while a
/// drag's pointer sits near its edge.
public enum KanbanAutoscrollDirection: Equatable {
    case none
    case negative(magnitude: CGFloat)
    case positive(magnitude: CGFloat)
}

public enum KanbanAutoscrollCalculator {
    /// `edgeBand` is the distance in points from either edge of `bounds`
    /// within which autoscroll engages. Speed ramps linearly from 0 at the
    /// band's inner boundary to `maxSpeed` at the outer edge itself.
    public static func direction(
        pointerPosition: CGFloat,
        bounds: ClosedRange<CGFloat>,
        edgeBand: CGFloat,
        maxSpeed: CGFloat
    ) -> KanbanAutoscrollDirection {
        guard bounds.contains(pointerPosition) else { return .none }

        let lowerBandEdge = bounds.lowerBound + edgeBand
        let upperBandEdge = bounds.upperBound - edgeBand

        if pointerPosition < lowerBandEdge {
            let proximity = (lowerBandEdge - pointerPosition) / edgeBand
            return .negative(magnitude: maxSpeed * min(proximity, 1))
        }
        if pointerPosition > upperBandEdge {
            let proximity = (pointerPosition - upperBandEdge) / edgeBand
            return .positive(magnitude: maxSpeed * min(proximity, 1))
        }
        return .none
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter KanbanAutoscrollTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/AdvancedKanban/Engine/KanbanAutoscroll.swift Tests/AdvancedKanbanTests/KanbanAutoscrollTests.swift
git commit -m "Add KanbanAutoscrollCalculator edge-band speed ramp"
```

---

## Task 7: Frame-tracking preference key and observable drag state

**Files:**
- Create: `Sources/AdvancedKanban/Engine/KanbanFramePreferenceKey.swift`
- Create: `Sources/AdvancedKanban/Engine/KanbanDragState.swift`
- Test: `Tests/AdvancedKanbanTests/KanbanDragStateTests.swift`

**Interfaces:**
- Consumes: `KanbanCardFrame`, `KanbanColumnZone`, `KanbanInsertionResolver` (Task 3).
- Produces: `KanbanFrame` enum (non-generic, `AnyHashable` ids — `.card(AnyHashable, CGRect)`, `.columnZone(AnyHashable, CGRect)`), `KanbanFramePreferenceKey: PreferenceKey` (also non-generic — see the note in Step 3 on why this must not be parameterized), `@Observable final class KanbanDragState<CardID: Hashable, ColumnID: Hashable>` with `draggedCardID: CardID?` (read-only outside), `proposedColumnID: ColumnID?`, `proposedIndex: Int?`, methods `beginDrag(cardID:)`, `updatePointer(location:cardFrames:columnZones:cardColumns:cardOrder:)`, `endDrag()`.

- [ ] **Step 1: Write the failing test**

`Tests/AdvancedKanbanTests/KanbanDragStateTests.swift`:
```swift
import Testing
import CoreGraphics
@testable import AdvancedKanban

@Suite struct KanbanDragStateTests {
    @Test func beginDragSetsDraggedCardID() {
        let state = KanbanDragState<String, String>()
        state.beginDrag(cardID: "a")
        #expect(state.draggedCardID == "a")
    }

    @Test func updatePointerSetsProposedColumnAndIndex() {
        let state = KanbanDragState<String, String>()
        state.beginDrag(cardID: "a")
        state.updatePointer(
            location: CGPoint(x: 100, y: 10),
            cardFrames: [
                KanbanCardFrame(cardID: "a", frame: CGRect(x: 0, y: 0, width: 200, height: 50)),
                KanbanCardFrame(cardID: "b", frame: CGRect(x: 0, y: 50, width: 200, height: 50)),
            ],
            columnZones: [
                KanbanColumnZone(columnID: "todo", frame: CGRect(x: 0, y: 0, width: 200, height: 100)),
            ],
            cardColumns: ["a": "todo", "b": "todo"],
            cardOrder: ["todo": ["a", "b"]]
        )
        #expect(state.proposedColumnID == "todo")
        #expect(state.proposedIndex == 0)
    }

    @Test func endDragClearsAllState() {
        let state = KanbanDragState<String, String>()
        state.beginDrag(cardID: "a")
        state.endDrag()
        #expect(state.draggedCardID == nil)
        #expect(state.proposedColumnID == nil)
        #expect(state.proposedIndex == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KanbanDragStateTests`
Expected: FAIL — `KanbanDragState` doesn't exist yet.

- [ ] **Step 3: Write `KanbanFramePreferenceKey.swift`**

```swift
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
```

- [ ] **Step 4: Write `KanbanDragState.swift`**

```swift
import CoreGraphics
import Observation

/// In-progress drag state, observed by the view layer. Plain Swift — not a
/// `View` — so `KanbanDragStateTests` exercises it without hosting any view
/// hierarchy.
@Observable
public final class KanbanDragState<CardID: Hashable, ColumnID: Hashable> {
    public private(set) var draggedCardID: CardID?
    public private(set) var pointerLocation: CGPoint = .zero
    public private(set) var proposedColumnID: ColumnID?
    public private(set) var proposedIndex: Int?
    public private(set) var dropDecision: WIPLimitDropDecision = .accept

    public init() {}

    public func beginDrag(cardID: CardID) {
        draggedCardID = cardID
    }

    public func updatePointer(
        location: CGPoint,
        cardFrames: [KanbanCardFrame<CardID>],
        columnZones: [KanbanColumnZone<ColumnID>],
        cardColumns: [CardID: ColumnID],
        cardOrder: [ColumnID: [CardID]]
    ) {
        pointerLocation = location
        guard let resolved = KanbanInsertionResolver.resolve(
            pointerLocation: location,
            cardFrames: cardFrames,
            columnZones: columnZones,
            cardColumns: cardColumns,
            cardOrder: cardOrder
        ) else {
            return
        }
        proposedColumnID = resolved.columnID
        proposedIndex = resolved.index
    }

    public func setDropDecision(_ decision: WIPLimitDropDecision) {
        dropDecision = decision
    }

    public func endDrag() {
        draggedCardID = nil
        pointerLocation = .zero
        proposedColumnID = nil
        proposedIndex = nil
        dropDecision = .accept
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter KanbanDragStateTests`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/AdvancedKanban/Engine/KanbanFramePreferenceKey.swift Sources/AdvancedKanban/Engine/KanbanDragState.swift Tests/AdvancedKanbanTests/KanbanDragStateTests.swift
git commit -m "Add frame-tracking preference key and observable KanbanDragState"
```

---

## Task 8: Theme and environment injection

**Files:**
- Create: `Sources/AdvancedKanban/Environment/KanbanTheme.swift`
- Create: `Sources/AdvancedKanban/Environment/EnvironmentValues+KanbanTheme.swift`
- Test: `Tests/AdvancedKanbanTests/KanbanThemeTests.swift`

**Interfaces:**
- Produces: `KanbanTheme` struct (fields per spec §9), `KanbanTheme.default` static property, `EnvironmentValues.kanbanTheme`, `View.kanbanTheme(_:)` modifier.

- [ ] **Step 1: Write the failing test**

`Tests/AdvancedKanbanTests/KanbanThemeTests.swift`:
```swift
import Testing
import SwiftUI
@testable import AdvancedKanban

@Suite struct KanbanThemeTests {
    @Test func defaultThemeHasNonZeroCornerRadiusAndSpacing() {
        let theme = KanbanTheme.default
        #expect(theme.cardCornerRadius > 0)
        #expect(theme.cardSpacing > 0)
        #expect(theme.columnWidth > 0)
    }

    @Test func environmentDefaultsToDefaultTheme() {
        let values = EnvironmentValues()
        #expect(values.kanbanTheme.cardCornerRadius == KanbanTheme.default.cardCornerRadius)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KanbanThemeTests`
Expected: FAIL — `KanbanTheme` and `EnvironmentValues.kanbanTheme` don't exist yet.

- [ ] **Step 3: Write `KanbanTheme.swift`**

```swift
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
```

- [ ] **Step 4: Write `EnvironmentValues+KanbanTheme.swift`**

```swift
import SwiftUI

private struct KanbanThemeKey: EnvironmentKey {
    static let defaultValue = KanbanTheme.default
}

extension EnvironmentValues {
    public var kanbanTheme: KanbanTheme {
        get { self[KanbanThemeKey.self] }
        set { self[KanbanThemeKey.self] = newValue }
    }
}

extension View {
    /// Applies a `KanbanTheme` to `KanbanBoard` (and any custom content
    /// that reads `@Environment(\.kanbanTheme)`) within this view subtree.
    public func kanbanTheme(_ theme: KanbanTheme) -> some View {
        environment(\.kanbanTheme, theme)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter KanbanThemeTests`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/AdvancedKanban/Environment Tests/AdvancedKanbanTests/KanbanThemeTests.swift
git commit -m "Add KanbanTheme and environment injection"
```

---

## Task 9: KanbanCardView chrome and drag ghost overlay

**Files:**
- Create: `Sources/AdvancedKanban/Views/KanbanCardView.swift`
- Create: `Sources/AdvancedKanban/Views/KanbanDragGhostOverlay.swift`

**Interfaces:**
- Consumes: `KanbanTheme` (Task 8), `KanbanCardFrame`, `KanbanFrame`, `KanbanFramePreferenceKey` (Tasks 3, 7).
- Produces: `KanbanCardView<Card: KanbanCard, Content: View>` (wraps consumer content with chrome, reports its frame, exposes a `.gesture`-attachment point used by `KanbanColumnView` in Task 10), `KanbanDragGhostOverlay<Content: View>` (floating view following a `CGPoint`).

- [ ] **Step 1: Write `KanbanCardView.swift`**

```swift
import SwiftUI

/// Renders one card's chrome (background, border, corner radius, shadow,
/// drag/WIP-warning state styling) around consumer-supplied content, and
/// reports its own frame via `KanbanFramePreferenceKey` so the drag engine
/// can hit-test against it.
public struct KanbanCardView<Card: KanbanCard, Content: View>: View {
    @Environment(\.kanbanTheme) private var theme

    let card: Card
    let columnID: AnyHashable
    let isBeingDragged: Bool
    let isOverWIPWarning: Bool
    @ViewBuilder let content: (Card) -> Content

    public init(
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

    public var body: some View {
        content(card)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .strokeBorder(isOverWIPWarning ? theme.wipLimitWarningColor : theme.cardBorder, lineWidth: isOverWIPWarning ? 2 : 1)
            )
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
```

Add this to `KanbanCardView.swift` above the struct — the single shared
named coordinate space used by every reporter and by `KanbanBoard`:

```swift
/// Shared named coordinate space for all frame reporting/hit-testing across
/// `KanbanBoard`, `KanbanColumnView`, and `KanbanCardView`.
enum KanbanCoordinateSpace {
    static let name = "AdvancedKanban.board"
}
```

...and use `.named(KanbanCoordinateSpace.name)` in the `GeometryReader`
above instead of the forward reference. This is the **only** place
`KanbanCoordinateSpace` is declared — Task 11 references it, it does not
redeclare it.

- [ ] **Step 2: Write `KanbanDragGhostOverlay.swift`**

```swift
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
```

- [ ] **Step 3: Verify the package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/AdvancedKanban/Views/KanbanCardView.swift Sources/AdvancedKanban/Views/KanbanDragGhostOverlay.swift
git commit -m "Add KanbanCardView chrome and drag ghost overlay"
```

---

## Task 10: KanbanColumnView

**Files:**
- Create: `Sources/AdvancedKanban/Views/KanbanColumnView.swift`

**Interfaces:**
- Consumes: `KanbanColumn` (Task 2), `KanbanTheme` (Task 8), `KanbanCardView` (Task 9), `KanbanFramePreferenceKey`/`KanbanFrame` (Task 7), `WIPLimitDropDecision` (Task 5).
- Produces: `KanbanColumnView<Column: KanbanColumn, CardContent: View, ColumnHeader: View>` — renders header (with WIP count/warning), collapse toggle, and the card list with an explicit empty-column drop-zone placeholder. Exposes `onToggleCollapse: () -> Void` and forwards per-card drag gesture callbacks up via closures so `KanbanBoard` (Task 11) owns the single shared `KanbanDragState`.

- [ ] **Step 1: Write `KanbanColumnView.swift`**

```swift
import SwiftUI

public struct KanbanColumnView<Column: KanbanColumn, CardContent: View, ColumnHeader: View>: View {
    @Environment(\.kanbanTheme) private var theme

    let column: Column
    let draggedCardID: Column.Card.ID?
    let wipDecision: WIPLimitDropDecision
    let onToggleCollapse: () -> Void
    @ViewBuilder let cardContent: (Column.Card) -> CardContent
    @ViewBuilder let columnHeader: (Column) -> ColumnHeader
    let cardGesture: (Column.Card) -> AnyGesture<Void>

    public init(
        column: Column,
        draggedCardID: Column.Card.ID?,
        wipDecision: WIPLimitDropDecision,
        onToggleCollapse: @escaping () -> Void,
        @ViewBuilder cardContent: @escaping (Column.Card) -> CardContent,
        @ViewBuilder columnHeader: @escaping (Column) -> ColumnHeader,
        cardGesture: @escaping (Column.Card) -> AnyGesture<Void>
    ) {
        self.column = column
        self.draggedCardID = draggedCardID
        self.wipDecision = wipDecision
        self.onToggleCollapse = onToggleCollapse
        self.cardContent = cardContent
        self.columnHeader = columnHeader
        self.cardGesture = cardGesture
    }

    private var isOverWIPWarning: Bool {
        wipDecision == .acceptWithWarning
    }

    public var body: some View {
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
                    ForEach(column.cards) { card in
                        KanbanCardView(
                            card: card,
                            columnID: AnyHashable(column.id),
                            isBeingDragged: card.id == draggedCardID,
                            isOverWIPWarning: isOverWIPWarning,
                            content: cardContent
                        )
                        .gesture(cardGesture(card))
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

    /// Keeps an empty column a valid, reachable drop target — without this,
    /// a column with zero cards has no frame to hit-test against.
    private var emptyDropZonePlaceholder: some View {
        RoundedRectangle(cornerRadius: theme.cardCornerRadius)
            .strokeBorder(theme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4]))
            .frame(height: 60)
            .overlay(Text("Drop here").font(.caption).foregroundStyle(.secondary))
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `swift build`
Expected: Build succeeds. (`AnyGesture<Void>` parameter is a placeholder shape used by this task only; Task 11 replaces `cardGesture`'s call sites with the real gesture — if `swift build` flags an unused-generic-parameter warning, that's expected at this stage and resolved by Task 11.)

- [ ] **Step 3: Commit**

```bash
git add Sources/AdvancedKanban/Views/KanbanColumnView.swift
git commit -m "Add KanbanColumnView with header, WIP display, collapse, empty drop zone"
```

---

## Task 11: KanbanBoard — assembly, gesture wiring, autoscroll, onMove

**Files:**
- Create: `Sources/AdvancedKanban/Views/KanbanBoard.swift`
- Modify: `Sources/AdvancedKanban/Views/KanbanColumnView.swift` (replace the `cardGesture: (Column.Card) -> AnyGesture<Void>` placeholder with a concrete `DragGesture` built inline by `KanbanBoard` and passed down as `some Gesture`)
- Modify: `Sources/AdvancedKanban/Views/KanbanCardView.swift` (remove the forward-reference note from Task 9 — coordinate space now consistently uses `KanbanCoordinateSpace.name`)

**Interfaces:**
- Consumes: everything from Tasks 2–10.
- Produces: `public struct KanbanBoard<Column: KanbanColumn, CardContent: View, ColumnHeader: View>: View` with the exact initializer from spec §6:
  ```swift
  public init(
      columns: Binding<[Column]>,
      wipLimitBehavior: WIPLimitBehavior = .warnOnly,
      onMove: ((KanbanMove<Column.Card.ID, Column.ID>) -> Void)? = nil,
      @ViewBuilder cardContent: @escaping (Column.Card) -> CardContent,
      @ViewBuilder columnHeader: @escaping (Column) -> ColumnHeader
  )
  ```

- [ ] **Step 1: Replace `KanbanColumnView`'s gesture parameter with a concrete generic type**

`some Gesture` isn't legal in a stored closure-property position, so make
`KanbanColumnView` generic over the gesture type instead of using `AnyGesture`.
In `Sources/AdvancedKanban/Views/KanbanColumnView.swift`:

1. Change the type declaration from
   `public struct KanbanColumnView<Column: KanbanColumn, CardContent: View, ColumnHeader: View>: View {`
   to
   `public struct KanbanColumnView<Column: KanbanColumn, CardContent: View, ColumnHeader: View, CardGesture: Gesture>: View {`
2. Change the stored property from `let cardGesture: (Column.Card) -> AnyGesture<Void>` to
   `let cardGesture: (Column.Card) -> CardGesture`.
3. Change the initializer parameter from `cardGesture: @escaping (Column.Card) -> AnyGesture<Void>`
   to `cardGesture: @escaping (Column.Card) -> CardGesture`.

The `.gesture(cardGesture(card))` call site is unchanged — Swift infers
`CardGesture` from the closure `KanbanBoard` passes in (Step 2 below).

- [ ] **Step 2: Write `KanbanBoard.swift`**

```swift
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
```

- [ ] **Step 3: Verify the package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 4: Verify all engine unit tests still pass**

Run: `swift test`
Expected: All tests from Tasks 2–8 PASS (view code isn't unit tested directly, per spec §13, but must not have broken the engine it wraps).

- [ ] **Step 5: Commit**

```bash
git add Sources/AdvancedKanban/Views
git commit -m "Add KanbanBoard: assembly, drag gesture wiring, autoscroll hookup, onMove"
```

---

## Task 12: Board-driven autoscroll

**Files:**
- Modify: `Sources/AdvancedKanban/Views/KanbanBoard.swift`

**Interfaces:**
- Consumes: `KanbanAutoscrollCalculator` (Task 6).
- Produces: horizontal autoscroll of the board's `ScrollView` while a drag's pointer sits near the leading/trailing edge, using `ScrollViewReader`/`scrollPosition` state added in this task.

- [ ] **Step 1: Add scroll-position state and a `ScrollViewReader` id per column**

In `KanbanBoard`, add:
```swift
@State private var scrollPosition = ScrollPosition()
@State private var boardBounds: CGRect = .zero
```

Wrap the existing `ScrollView(.horizontal) { ... }` body with `.scrollPosition($scrollPosition)` and add a `GeometryReader`-based bounds report:
```swift
.background(
    GeometryReader { proxy in
        Color.clear.onAppear { boardBounds = proxy.frame(in: .named(KanbanCoordinateSpace.name)) }
            .onChange(of: proxy.size) { _, _ in boardBounds = proxy.frame(in: .named(KanbanCoordinateSpace.name)) }
    }
)
```

- [ ] **Step 2: Add an autoscroll timer driven by `dragState.pointerLocation`**

Add a `Timer.publish`-based subscription that only runs while dragging:
```swift
@State private var autoscrollTimer: Timer?

private func startAutoscrollIfNeeded() {
    guard autoscrollTimer == nil else { return }
    autoscrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
        guard dragState.draggedCardID != nil, boardBounds.width > 0 else { return }
        let direction = KanbanAutoscrollCalculator.direction(
            pointerPosition: dragState.pointerLocation.x,
            bounds: boardBounds.minX...boardBounds.maxX,
            edgeBand: 60,
            maxSpeed: 12
        )
        switch direction {
        case .none:
            break
        case .negative(let magnitude):
            scrollPosition.scrollTo(x: max(0, (scrollPosition.point?.x ?? 0) - magnitude))
        case .positive(let magnitude):
            scrollPosition.scrollTo(x: (scrollPosition.point?.x ?? 0) + magnitude)
        }
    }
}

private func stopAutoscroll() {
    autoscrollTimer?.invalidate()
    autoscrollTimer = nil
}
```

- [ ] **Step 3: Wire timer start/stop into the drag gesture**

In `dragGesture(for:in:)`'s `.onChanged`, after `dragState.beginDrag(...)`, add `startAutoscrollIfNeeded()`. In `.onEnded`, after `dragState.endDrag()`, add `stopAutoscroll()`.

- [ ] **Step 4: Verify the package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 5: Manual verification note**

Automated verification of `scrollPosition.scrollTo` firing correctly requires
a hosted view (out of scope for unit tests per spec §13) — verify visually
in the example app once Task 15 exists, by dragging a card to within 60pt of
either horizontal edge and confirming the board scrolls.

- [ ] **Step 6: Commit**

```bash
git add Sources/AdvancedKanban/Views/KanbanBoard.swift
git commit -m "Wire KanbanAutoscrollCalculator into KanbanBoard's horizontal ScrollView"
```

---

## Task 13: VoiceOver accessibility actions

**Files:**
- Modify: `Sources/AdvancedKanban/Views/KanbanColumnView.swift` (add accessibility modifiers to each rendered `KanbanCardView`)
- Modify: `Sources/AdvancedKanban/Views/KanbanBoard.swift` (pass a `moveCard(_:to:index:)` closure down to `KanbanColumnView` for actions to call)

**Interfaces:**
- Consumes: `KanbanMoveResolver` (Task 4), `KanbanBoard.applyMove(_:)` (Task 11).
- Produces: each card exposes `.accessibilityValue("\(index) of \(count) in \(columnTitle)")` and `.accessibilityAction`s: "Move Up", "Move Down", one "Move to <Column>" per other column — all calling the same `moveCard` closure, which calls `KanbanMoveResolver.resolve` then `KanbanBoard.applyMove(_:)`.

- [ ] **Step 1: Add a `moveCard` closure parameter to `KanbanColumnView`**

Add to `KanbanColumnView`'s stored properties and initializer:
```swift
let allColumns: [Column]
let moveCard: (_ cardID: Column.Card.ID, _ toColumnID: Column.ID, _ toIndex: Int) -> Void
```

- [ ] **Step 2: Attach accessibility value + actions to each card**

In `cardList`, change the `ForEach` body to wrap each `KanbanCardView` with accessibility modifiers:

```swift
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
        moveCard(card.id, column.id, index + 1)
    }
    .accessibilityActions {
        ForEach(allColumns.filter { $0.id != column.id }) { otherColumn in
            Button("Move to \(accessibilityTitle(for: otherColumn))") {
                moveCard(card.id, otherColumn.id, otherColumn.cards.count)
            }
        }
    }
}
```

Add a helper for the column title (falls back to a generic label since the
consumer's `columnHeader` view isn't introspectable as text):
```swift
private var accessibilityColumnTitle: String {
    accessibilityTitle(for: column)
}

private func accessibilityTitle(for column: Column) -> String {
    "column \(String(describing: column.id))"
}
```

Note: this generic fallback ("column <id>") is a known v1 limitation — a
consumer's `columnHeader` may render a nicer title than the raw id, but the
board has no protocol-level access to a display string. Document this in
Task 16's README as a customization note: consumers who want a specific
VoiceOver-announced column name should make their `KanbanColumn`-conforming
type's `id` itself be (or be convertible to) that display string, or wait
for a future `displayName` protocol requirement.

- [ ] **Step 3: Wire `moveCard` through `KanbanBoard`**

In `KanbanBoard.body`, pass to each `KanbanColumnView`:
```swift
allColumns: columns,
moveCard: { cardID, toColumnID, toIndex in
    guard let sourceColumn = columns.first(where: { $0.cards.contains(where: { $0.id == cardID }) }),
          let sourceIndex = sourceColumn.cards.firstIndex(where: { $0.id == cardID }),
          let move = KanbanMoveResolver.resolve(
              cardID: cardID,
              sourceColumnID: sourceColumn.id,
              sourceIndex: sourceIndex,
              destinationColumnID: toColumnID,
              destinationIndex: toIndex
          )
    else { return }
    applyMove(move)
    onMove?(move)
}
```

- [ ] **Step 4: Verify the package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/AdvancedKanban/Views/KanbanColumnView.swift Sources/AdvancedKanban/Views/KanbanBoard.swift
git commit -m "Add VoiceOver accessibility value + move actions routed through KanbanMoveResolver"
```

---

## Task 14: Keyboard move-mode

**Files:**
- Modify: `Sources/AdvancedKanban/Views/KanbanColumnView.swift` (add focus + key-press handling to each card)

**Interfaces:**
- Consumes: `moveCard` closure (Task 13).
- Produces: focused card enters "move mode" on `Space`/`Return` (theme-highlighted), arrow keys shift it (including across columns at a boundary), `Return` commits, `Escape` cancels.

- [ ] **Step 1: Add move-mode state to `KanbanColumnView`**

```swift
@State private var moveModeCardID: Column.Card.ID?
@FocusState private var focusedCardID: Column.Card.ID?
```

- [ ] **Step 2: Add focus, highlight, and key handling to each card**

Extend the `ForEach` body from Task 13 with:
```swift
.focusable()
.focused($focusedCardID, equals: card.id)
.overlay(
    RoundedRectangle(cornerRadius: theme.cardCornerRadius)
        .strokeBorder(theme.wipLimitWarningColor, lineWidth: moveModeCardID == card.id ? 2 : 0)
)
.onKeyPress(.space) {
    toggleMoveMode(for: card.id)
    return .handled
}
.onKeyPress(.return) {
    if moveModeCardID == card.id {
        moveModeCardID = nil
        return .handled
    }
    toggleMoveMode(for: card.id)
    return .handled
}
.onKeyPress(.escape) {
    guard moveModeCardID == card.id else { return .ignored }
    moveModeCardID = nil
    return .handled
}
.onKeyPress(.upArrow) {
    guard moveModeCardID == card.id, index > 0 else { return .ignored }
    moveCard(card.id, column.id, index - 1)
    return .handled
}
.onKeyPress(.downArrow) {
    guard moveModeCardID == card.id, index < column.cards.count - 1 else { return .ignored }
    moveCard(card.id, column.id, index + 1)
    return .handled
}
.onKeyPress(.leftArrow) {
    guard moveModeCardID == card.id, let previousColumn = column(before: column) else { return .ignored }
    moveCard(card.id, previousColumn.id, previousColumn.cards.count)
    return .handled
}
.onKeyPress(.rightArrow) {
    guard moveModeCardID == card.id, let nextColumn = column(after: column) else { return .ignored }
    moveCard(card.id, nextColumn.id, nextColumn.cards.count)
    return .handled
}
```

Add the supporting helpers:
```swift
private func toggleMoveMode(for cardID: Column.Card.ID) {
    moveModeCardID = (moveModeCardID == cardID) ? nil : cardID
}

private func column(before target: Column) -> Column? {
    guard let index = allColumns.firstIndex(where: { $0.id == target.id }), index > 0 else { return nil }
    return allColumns[index - 1]
}

private func column(after target: Column) -> Column? {
    guard let index = allColumns.firstIndex(where: { $0.id == target.id }), index < allColumns.count - 1 else { return nil }
    return allColumns[index + 1]
}
```

Note: after a cross-column move via left/right arrow, `moveModeCardID` still
holds the card's id but the card view instance it was attached to is gone
from this column's `ForEach` (the card moved to a different `KanbanColumnView`
instance). Reset `moveModeCardID` to `nil` immediately after calling
`moveCard` in the `.leftArrow`/`.rightArrow` handlers above (add
`moveModeCardID = nil` right before `return .handled` in both) so move mode
doesn't appear to silently "stick" on a card the user can no longer see move
further in this column. The user can re-enter move mode via `Space` on the
card's new column.

- [ ] **Step 3: Verify the package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/AdvancedKanban/Views/KanbanColumnView.swift
git commit -m "Add keyboard move-mode: Space/Return to pick up, arrows to move, Return/Escape to commit/cancel"
```

---

## Task 15: AdvancedKanbanSwiftData persistence adapter

**Files:**
- Create: `Sources/AdvancedKanbanSwiftData/SwiftDataKanbanCard.swift`
- Create: `Sources/AdvancedKanbanSwiftData/SwiftDataKanbanColumn.swift`
- Create: `Sources/AdvancedKanbanSwiftData/KanbanStore.swift`
- Test: `Tests/AdvancedKanbanTests/KanbanStoreTests.swift` (in the same test target; add `AdvancedKanbanSwiftData` as a dependency of `AdvancedKanbanTests` in `Package.swift`)

**Interfaces:**
- Consumes: `KanbanCard`, `KanbanColumn`, `KanbanMove` (Task 2), SwiftData.
- Produces: `@Model final class SwiftDataKanbanCard: KanbanCard` (fields: `id: UUID`, `title: String`, `sortIndex: Int`), `@Model final class SwiftDataKanbanColumn: KanbanColumn` (fields: `id: UUID`, `title: String`, `wipLimit: Int?`, `isCollapsed: Bool`, `cards: [SwiftDataKanbanCard]` computed from a `@Relationship`), `@MainActor final class KanbanStore` with `apply(_ move: KanbanMove<UUID, UUID>) throws` that reorders via `ModelContext` and saves.

- [ ] **Step 1: Update `Package.swift` to link the test target against `AdvancedKanbanSwiftData`**

Change the `testTarget` in `Package.swift` from:
```swift
.testTarget(
    name: "AdvancedKanbanTests",
    dependencies: ["AdvancedKanban"]
),
```
to:
```swift
.testTarget(
    name: "AdvancedKanbanTests",
    dependencies: ["AdvancedKanban", "AdvancedKanbanSwiftData"]
),
```

- [ ] **Step 2: Write the failing test**

`Tests/AdvancedKanbanTests/KanbanStoreTests.swift`:
```swift
import Testing
import SwiftData
@testable import AdvancedKanban
@testable import AdvancedKanbanSwiftData

@Suite struct KanbanStoreTests {
    @MainActor
    private func makeStore() throws -> (KanbanStore, ModelContext) {
        let schema = Schema([SwiftDataKanbanCard.self, SwiftDataKanbanColumn.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        return (KanbanStore(modelContext: context), context)
    }

    @MainActor
    @Test func applyingACrossColumnMoveReassignsTheCardsColumnAndSortIndex() throws {
        let (store, context) = try makeStore()

        let todo = SwiftDataKanbanColumn(id: UUID(), title: "Todo", wipLimit: nil, isCollapsed: false)
        let doing = SwiftDataKanbanColumn(id: UUID(), title: "Doing", wipLimit: nil, isCollapsed: false)
        let card = SwiftDataKanbanCard(id: UUID(), title: "Write tests", sortIndex: 0)
        card.column = todo
        context.insert(todo)
        context.insert(doing)
        context.insert(card)
        try context.save()

        let move = KanbanMove(
            cardID: card.id, sourceColumnID: todo.id, sourceIndex: 0,
            destinationColumnID: doing.id, destinationIndex: 0
        )
        try store.apply(move)

        #expect(card.column?.id == doing.id)
        #expect(card.sortIndex == 0)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --filter KanbanStoreTests`
Expected: FAIL — `SwiftDataKanbanCard`, `SwiftDataKanbanColumn`, `KanbanStore` don't exist yet.

- [ ] **Step 4: Write `SwiftDataKanbanCard.swift`**

```swift
import SwiftData
import Foundation
import AdvancedKanban

@Model
public final class SwiftDataKanbanCard {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var sortIndex: Int
    public var column: SwiftDataKanbanColumn?

    public init(id: UUID = UUID(), title: String, sortIndex: Int) {
        self.id = id
        self.title = title
        self.sortIndex = sortIndex
    }
}

extension SwiftDataKanbanCard: KanbanCard {
    public static func == (lhs: SwiftDataKanbanCard, rhs: SwiftDataKanbanCard) -> Bool {
        lhs.id == rhs.id
    }
}
```

- [ ] **Step 5: Write `SwiftDataKanbanColumn.swift`**

```swift
import SwiftData
import Foundation
import AdvancedKanban

@Model
public final class SwiftDataKanbanColumn {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var wipLimit: Int?
    public var isCollapsed: Bool

    @Relationship(deleteRule: .cascade, inverse: \SwiftDataKanbanCard.column)
    public var cardModels: [SwiftDataKanbanCard] = []

    public init(id: UUID = UUID(), title: String, wipLimit: Int?, isCollapsed: Bool) {
        self.id = id
        self.title = title
        self.wipLimit = wipLimit
        self.isCollapsed = isCollapsed
    }
}

extension SwiftDataKanbanColumn: KanbanColumn {
    public var cards: [SwiftDataKanbanCard] {
        get { cardModels.sorted { $0.sortIndex < $1.sortIndex } }
        set { cardModels = newValue }
    }
}
```

- [ ] **Step 6: Write `KanbanStore.swift`**

```swift
import SwiftData
import Foundation
import AdvancedKanban

public enum KanbanStoreError: Error {
    case cardNotFound
    case columnNotFound
}

@MainActor
public final class KanbanStore {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Applies a `KanbanMove` (as emitted by `KanbanBoard`'s `onMove`) to
    /// the SwiftData store: reassigns the card's column and renumbers
    /// `sortIndex` for every card in the destination column, then saves.
    public func apply(_ move: KanbanMove<UUID, UUID>) throws {
        let cardID = move.cardID
        let cardDescriptor = FetchDescriptor<SwiftDataKanbanCard>(
            predicate: #Predicate { $0.id == cardID }
        )
        guard let card = try modelContext.fetch(cardDescriptor).first else {
            throw KanbanStoreError.cardNotFound
        }

        let destinationColumnID = move.destinationColumnID
        let columnDescriptor = FetchDescriptor<SwiftDataKanbanColumn>(
            predicate: #Predicate { $0.id == destinationColumnID }
        )
        guard let destinationColumn = try modelContext.fetch(columnDescriptor).first else {
            throw KanbanStoreError.columnNotFound
        }

        var destinationCards = destinationColumn.cards.filter { $0.id != card.id }
        let clampedIndex = min(max(move.destinationIndex, 0), destinationCards.count)
        destinationCards.insert(card, at: clampedIndex)

        for (index, destinationCard) in destinationCards.enumerated() {
            destinationCard.sortIndex = index
            destinationCard.column = destinationColumn
        }

        try modelContext.save()
    }
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `swift test --filter KanbanStoreTests`
Expected: PASS (1 test).

- [ ] **Step 8: Run the full test suite**

Run: `swift test`
Expected: All tests across both targets PASS.

- [ ] **Step 9: Commit**

```bash
git add Package.swift Sources/AdvancedKanbanSwiftData Tests/AdvancedKanbanTests/KanbanStoreTests.swift
git commit -m "Add AdvancedKanbanSwiftData persistence adapter"
```

---

## Task 16: Example app

**Files:**
- Create: `Example/project.yml` (XcodeGen spec)
- Create: `Example/AdvancedKanbanExample/AdvancedKanbanExampleApp.swift`
- Create: `Example/AdvancedKanbanExample/Model/ExampleTask.swift`
- Create: `Example/AdvancedKanbanExample/Model/ExampleColumn.swift`
- Create: `Example/AdvancedKanbanExample/Views/BoardScreen.swift`
- Create: `Example/AdvancedKanbanExample/Views/TaskCardContent.swift`
- Create: `Example/AdvancedKanbanExample/Views/ThemePicker.swift`
- Create: `Example/AdvancedKanbanExample/Assets.xcassets/` (app icon placeholder, accent color)
- Create: `Example/README.md`

**Interfaces:**
- Consumes: `KanbanBoard`, `KanbanCard`, `KanbanColumn`, `KanbanTheme`, `.kanbanTheme(_:)`, `WIPLimitBehavior`, `AdvancedKanbanSwiftData` types (all prior tasks).

- [ ] **Step 1: Confirm XcodeGen is available, installing if needed**

Run: `which xcodegen || brew install xcodegen`
Expected: `xcodegen` resolves to a binary path.

- [ ] **Step 2: Write `Example/project.yml`**

```yaml
name: AdvancedKanbanExample
options:
  bundleIdPrefix: com.nerdsnipe.advancedkanban
packages:
  AdvancedKanban:
    path: ..
targets:
  AdvancedKanbanExample:
    type: application
    platform: [iOS, macOS]
    deploymentTarget:
      iOS: "17.0"
      macOS: "14.0"
    sources: [AdvancedKanbanExample]
    dependencies:
      - package: AdvancedKanban
        product: AdvancedKanban
      - package: AdvancedKanban
        product: AdvancedKanbanSwiftData
    info:
      path: AdvancedKanbanExample/Info.plist
      properties:
        UILaunchScreen: {}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.nerdsnipe.advancedkanban.example
        SWIFT_VERSION: "5.9"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

- [ ] **Step 3: Write the example domain model**

`Example/AdvancedKanbanExample/Model/ExampleTask.swift`:
```swift
import Foundation
import AdvancedKanban

struct ExampleTask: KanbanCard {
    let id: UUID
    var title: String
    var assigneeInitials: String
    var priority: Priority

    enum Priority: String, CaseIterable {
        case low, medium, high

        var color: String {
            switch self {
            case .low: "green"
            case .medium: "orange"
            case .high: "red"
            }
        }
    }
}
```

`Example/AdvancedKanbanExample/Model/ExampleColumn.swift`:
```swift
import Foundation
import AdvancedKanban

struct ExampleColumn: KanbanColumn {
    let id: UUID
    var title: String
    var cards: [ExampleTask]
    var wipLimit: Int?
    var isCollapsed: Bool
}

extension ExampleColumn {
    static func seedData() -> [ExampleColumn] {
        [
            ExampleColumn(
                id: UUID(), title: "Backlog",
                cards: [
                    ExampleTask(id: UUID(), title: "Design onboarding flow", assigneeInitials: "JD", priority: .medium),
                    ExampleTask(id: UUID(), title: "Research competitor apps", assigneeInitials: "AS", priority: .low),
                ],
                wipLimit: nil, isCollapsed: false
            ),
            ExampleColumn(
                id: UUID(), title: "In Progress",
                cards: [
                    ExampleTask(id: UUID(), title: "Build KanbanBoard view", assigneeInitials: "JD", priority: .high),
                ],
                wipLimit: 3, isCollapsed: false
            ),
            ExampleColumn(
                id: UUID(), title: "Review",
                cards: [],
                wipLimit: 2, isCollapsed: false
            ),
            ExampleColumn(
                id: UUID(), title: "Done",
                cards: [
                    ExampleTask(id: UUID(), title: "Set up SPM package", assigneeInitials: "AS", priority: .low),
                ],
                wipLimit: nil, isCollapsed: false
            ),
        ]
    }
}
```

- [ ] **Step 4: Write the card content view**

`Example/AdvancedKanbanExample/Views/TaskCardContent.swift`:
```swift
import SwiftUI

struct TaskCardContent: View {
    let task: ExampleTask

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.subheadline.weight(.medium))
            HStack {
                Text(task.priority.rawValue.capitalized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor.opacity(0.15))
                    .foregroundStyle(priorityColor)
                    .clipShape(Capsule())
                Spacer()
                Text(task.assigneeInitials)
                    .font(.caption2.weight(.semibold))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.gray.opacity(0.2)))
            }
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}
```

- [ ] **Step 5: Write the theme picker**

`Example/AdvancedKanbanExample/Views/ThemePicker.swift`:
```swift
import SwiftUI
import AdvancedKanban

enum ExampleTheme: String, CaseIterable, Identifiable {
    case standard, highContrast
    var id: String { rawValue }

    var kanbanTheme: KanbanTheme {
        switch self {
        case .standard:
            .default
        case .highContrast:
            KanbanTheme(
                columnBackground: .black,
                cardBackground: .white,
                cardBorder: .yellow,
                cardCornerRadius: 4,
                cardSpacing: 10,
                columnWidth: 300,
                columnCornerRadius: 6,
                wipLimitWarningColor: .red,
                dragGhostOpacity: 1.0,
                dropAnimation: .easeInOut(duration: 0.2)
            )
        }
    }
}

struct ThemePicker: View {
    @Binding var selection: ExampleTheme

    var body: some View {
        Picker("Theme", selection: $selection) {
            ForEach(ExampleTheme.allCases) { theme in
                Text(theme == .standard ? "Standard" : "High Contrast").tag(theme)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}
```

- [ ] **Step 6: Write the board screen**

`Example/AdvancedKanbanExample/Views/BoardScreen.swift`:
```swift
import SwiftUI
import AdvancedKanban

struct BoardScreen: View {
    @State private var columns = ExampleColumn.seedData()
    @State private var selectedTheme: ExampleTheme = .standard
    @State private var lastMoveDescription: String = "No moves yet"

    var body: some View {
        VStack(spacing: 12) {
            ThemePicker(selection: $selectedTheme)
            Text(lastMoveDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            KanbanBoard(
                columns: $columns,
                wipLimitBehavior: .preventDrop,
                onMove: { move in
                    lastMoveDescription = "Moved \(move.cardID) to column \(move.destinationColumnID) at index \(move.destinationIndex)"
                },
                cardContent: { task in TaskCardContent(task: task) },
                columnHeader: { column in
                    Text(column.title).font(.headline)
                }
            )
        }
        .kanbanTheme(selectedTheme.kanbanTheme)
        .padding(.top)
    }
}
```

- [ ] **Step 7: Write the app entry point**

`Example/AdvancedKanbanExample/AdvancedKanbanExampleApp.swift`:
```swift
import SwiftUI

@main
struct AdvancedKanbanExampleApp: App {
    var body: some Scene {
        WindowGroup {
            BoardScreen()
        }
    }
}
```

- [ ] **Step 8: Generate the Xcode project and add a placeholder asset catalog**

Run:
```bash
cd Example
mkdir -p AdvancedKanbanExample/Assets.xcassets
cat > AdvancedKanbanExample/Assets.xcassets/Contents.json <<'EOF'
{ "info": { "author": "xcode", "version": 1 } }
EOF
xcodegen generate
cd ..
```
Expected: `Example/AdvancedKanbanExample.xcodeproj` is created.

- [ ] **Step 9: Build the example app for macOS to verify it compiles against the local package**

Run: `xcodebuild -project Example/AdvancedKanbanExample.xcodeproj -scheme AdvancedKanbanExample -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 10: Write `Example/README.md`**

```markdown
# AdvancedKanban Example

Open `AdvancedKanbanExample.xcodeproj` in Xcode and run the
`AdvancedKanbanExample` scheme on macOS or an iOS/iPadOS simulator. It
depends on the parent `AdvancedKanban` package via a local path, so it
always builds against the source in this repo.

Demonstrates:
- Cross-column drag reorder, with a WIP limit set to `.preventDrop` on the
  "In Progress" and "Review" columns.
- Custom card content (priority chip + assignee initials) via the
  `cardContent` view builder.
- Theme switching (Standard / High Contrast) via `.kanbanTheme(_:)`.
- Column collapse (tap the chevron in a column header).
- Keyboard reorder: focus a card (Tab), press Space to enter move mode,
  arrow keys to move (including across columns), Return to commit, Escape
  to cancel.
- VoiceOver: enable VoiceOver, navigate to a card, use the rotor to find
  "Move Up" / "Move Down" / "Move to <Column>" actions.
```

- [ ] **Step 11: Commit**

```bash
git add Example
git commit -m "Add AdvancedKanbanExample app demonstrating the full package"
```

---

## Task 17: README, CONTRIBUTING, and package doc polish

**Files:**
- Modify: `README.md` (full documentation, replacing the Task 1 stub)
- Create: `CONTRIBUTING.md`

**Interfaces:**
- None — documentation only.

- [ ] **Step 1: Write the full `README.md`**

Include, in order: one-paragraph pitch, minimal "add a board in 3 steps" code
sample (conform a card type, conform a column type, call `KanbanBoard`),
feature list (WIP limits, collapse, keyboard + VoiceOver reorder, theming),
a link to the example app, a link to the design spec, installation via
Swift Package Manager (`.package(url: "https://github.com/<org>/AdvancedKanban", from: "1.0.0")`
— use a placeholder org name and note it needs updating once the repo has a
real remote), and the MIT license badge/section.

- [ ] **Step 2: Write `CONTRIBUTING.md`**

Cover: how to build (`swift build`), how to run tests (`swift test`), how to
run the example app (Task 16's `Example/README.md`), code style (no
third-party linter assumed — follow existing file conventions), and the PR
expectation that engine changes (`Sources/AdvancedKanban/Engine/`) come with
unit tests per the TDD pattern established in Tasks 3–7.

- [ ] **Step 3: Run the full test suite one final time**

Run: `swift test`
Expected: All tests across `AdvancedKanbanTests` PASS.

- [ ] **Step 4: Commit**

```bash
git add README.md CONTRIBUTING.md
git commit -m "Write full README and CONTRIBUTING docs"
```
