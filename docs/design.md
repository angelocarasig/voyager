# Voyager design

Design for Voyager v1, agreed on 2026-11-10. It builds on [brief.md](brief.md). Decision notes
live in the Basic Memory project `voyager`.

## Decisions

| # | Topic | Decision |
|---|---|---|
| 1 | Priority | Appearance first. Non-blocking NAS loading remains a baseline. |
| 2 | Scope | Minimal tier: sidebar, file list, open on double-click, Quick Look, keyboard navigation. |
| 3 | Minimum macOS | macOS 26. macOS 27 APIs need `#available` checks. |
| 4 | Window layout | Sidebar and content area, with a breadcrumb path bar in the toolbar. |
| 5 | File views | List and icon grid, toggled by one app-wide setting. |
| 6 | Keyboard | Finder's shortcuts plus Thunar extras. |
| 7 | Folder loading | Load in the background, show the full listing at once, spinner in the path bar. |

Out of v1: rename, trash, tabs, copy and move, drag and drop, live updates, thumbnails, tags and
search. Rename, trash, copy and move, drag and drop, thumbnails and undo have since been added;
their decisions are in Basic Memory.

## Window

```
┌──────────┬──────────────────────────────────┐
│ Home     │ ‹ ›  Home › Documents › Work   ◌  │
│ Desktop  ├──────────────────────────────────┤
│ Documents│ Name            Size   Modified  │
│ Downloads│ report.pdf      1.2 MB Today     │
│ ──────── │ notes.txt       4 KB   Yesterday │
│ archive  │                                  │
│ Media    │                                  │
│ ──────── │                                  │
│ Volumes  │                                  │
└──────────┴──────────────────────────────────┘
```

- `NavigationSplitView` with a sidebar and a content column. On macOS 26 the sidebar adopts
  Liquid Glass automatically (Apple, "Adopting Liquid Glass").
- Sidebar sections: home folders (Home, Desktop, Documents, Downloads), NAS shares listed in
  `settings.json` and connected through NetFS on click, and mounted volumes. The current folder's entry is highlighted when it is
  one of them.
- Toolbar: back and forward buttons, a breadcrumb path bar, a loading spinner and the
  list/grid toggle.

## File views

- **Details:** SwiftUI `Table` with Name, Date Modified, Size and Kind columns, plus optional
  columns. Clicking a header sorts.
- **Icon layouts:** extra large, large, medium and small icons, list, tiles and content, drawn
  with lazy grids.
- The layout, sort and grouping come from `settings.json` and can be remembered per folder.
- Every layout shares one selection, one sort order and a drag-to-select band.

If `Table` struggles with very large folders, replace it with an `NSTableView` wrapper. Very
large folders are a Finder-grade concern, so v1 does not plan for them.

## Keyboard

| Key | Action |
|---|---|
| Return, `⌘↓`, double-click | Open the folder, or open the file in its default app |
| Backspace, `⌘↑` | Go to the parent folder |
| `⌘[` / `⌘]` | Back / forward |
| `⌘L` | Edit the path as text |
| Typing letters | Jump to the first item whose name starts with them |
| Space | Quick Look the selection |
| Arrow keys | Move the selection; in the grid, up and down move by row |
| `⌘1` to `⌘8` | Choose a layout |
| F2 | Rename in place |
| `⌘Z` / `⇧⌘Z` | Undo / redo file changes |
| `⌘R` | Reload the current folder |

Return opens, so rename uses F2, as Windows does.

## Folder loading

1. Navigating to a folder cancels the load in progress and starts a new `Task`.
2. The task lists the folder off the main actor with
   `FileManager.contentsOfDirectory(at:includingPropertiesForKeys:options:)`, prefetching the
   name, size, modification date, type and directory flag.
3. When the task finishes, the sorted entries replace the view's contents in one update. The
   spinner shows while a task runs.
4. A failed listing (permission denied, share unmounted) shows an inline message in the content
   area, and the sidebar stays usable.

Folders are not watched for changes in v1. `⌘R` reloads.

## Platform

- Not sandboxed, distributed outside the Mac App Store. Reading protected folders needs Full
  Disk Access, which the user grants in System Settings.
- Files open with `NSWorkspace.open(_:)`. Quick Look uses SwiftUI's `quickLookPreview`.

## Open items

- Check whether `⌘L` conflicts with a standard macOS 26 shortcut. Not found in the local HIG
  copy.
- Decide how Voyager asks for Full Disk Access on first launch.
