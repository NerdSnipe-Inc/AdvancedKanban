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
