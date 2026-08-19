# Contributing to AdvancedKanban

## Building

```bash
swift build
```

Builds both library products (`AdvancedKanban` and `AdvancedKanbanSwiftData`).
Requires Swift 5.9+ and either Xcode with iOS 17 / macOS 14 SDKs or a
matching Swift toolchain on macOS.

## Testing

```bash
swift test
```

Runs the full suite in `Tests/AdvancedKanbanTests`, covering the drag
engine (`KanbanMoveResolverTests`, `KanbanInsertionResolverTests`,
`KanbanDragStateTests`, `KanbanAutoscrollTests`), WIP limit evaluation
(`WIPLimitEvaluatorTests`), theming (`KanbanThemeTests`), and the SwiftData
adapter (`KanbanStoreTests`). CI-equivalent verification also includes
building for both platforms:

```bash
xcodebuild build -scheme AdvancedKanban -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild build -scheme AdvancedKanban -destination 'platform=macOS'
```

(or the equivalent `swift build` invocations if you don't have Xcode
project generation set up — the package builds cleanly with plain SPM on
macOS.)

## Running the example app

See [`Example/README.md`](Example/README.md). Open
`Example/AdvancedKanbanExample.xcodeproj` in Xcode and run the
`AdvancedKanbanExample` scheme; it depends on this package via a local path,
so it always builds against the source in your working tree — it's the
fastest way to see a change (drag behavior, theming, keyboard/VoiceOver
reorder) actually working before you write or update a unit test for it.

## Code style

There's no linter (SwiftLint/SwiftFormat) wired into this repo — follow the
conventions already present in the file you're touching:

- Public API gets a doc comment (`///`) explaining *why*, not just what —
  see `Sources/AdvancedKanban/Protocols/KanbanCard.swift` for the tone to
  match.
- Engine types (`Sources/AdvancedKanban/Engine/`) are plain value types/pure
  functions with no SwiftUI dependency — keep it that way so they stay
  trivially unit-testable.
- View types live in `Sources/AdvancedKanban/Views/`; environment/theming
  plumbing lives in `Sources/AdvancedKanban/Environment/`. Match the
  existing file's layout (property declarations, `init`, then computed
  properties/body) rather than introducing a new structure.
- 4-space indentation, no trailing whitespace, one type per file, file name
  matches the primary type it declares.

## Pull requests

- **Engine changes come with unit tests.** Anything under
  `Sources/AdvancedKanban/Engine/` (move resolution, insertion index math,
  drag state, autoscroll, WIP limit evaluation) is pure logic and was built
  test-first — see `Tests/AdvancedKanbanTests/KanbanMoveResolverTests.swift`
  or `WIPLimitEvaluatorTests.swift` for the pattern. A PR that changes
  engine behavior without a corresponding test change will be asked to add
  one before merge.
- View-layer changes (`Sources/AdvancedKanban/Views/`) should at minimum be
  verified against the example app; add tests where the change is
  logic-bearing rather than purely visual.
- Run `swift test` locally before opening a PR — all tests must pass.
- Keep PRs focused: one behavioral change per PR is easier to review than a
  bundle of unrelated cleanups.
