# Voyager brief

## Intent

Voyager is a native macOS file manager with a modern, minimal design, in the spirit of Thunar on
Linux. It is a personal tool for daily navigation, not a full Finder replacement.

## Status

Idea stage. No design has been agreed and no code exists. The next step is a design conversation
with the user, then a design doc, then a plan.

## Known constraints

- Platform: macOS only. The development machine runs macOS 27.
- Stack: Swift and SwiftUI, per the user's global rules. AppKit is acceptable where SwiftUI falls
  short, such as large file lists.
- Distribution: outside the Mac App Store, since the sandbox is unworkable for a file manager.
  Reading everywhere needs Full Disk Access.
- macOS offers no supported way to replace Finder. Desktop, "Reveal in Finder" and similar system
  paths stay with Finder.

## Context

- The user's TrueNAS shares (archive, docker, Media, torrents, Z) are mounted over SMB at login
  and exposed at `/mnt/NAS/<share>`. Network listings are slow, so directory loading must never
  block the UI.
- Alternatives already reviewed: Marta, QSpace Pro, ForkLift, Commander One and Path Finder. The
  user chose to build instead.

## Rough scope tiers

| Tier | Contents | Estimate |
|---|---|---|
| Minimal | Sidebar, file list, open on double-click, Quick Look, keyboard navigation | A weekend |
| Daily driver | Copy and move with progress, trash and undo, rename, drag and drop, live updates, tabs | A few weeks |
| Finder-grade | Fast thumbnails, very large folders, tags, iCloud placeholders, search | Months |

## Hard parts

- Performance on folders with tens of thousands of entries.
- File operations that never lose data: conflicts, cancellation and partial failure.
- Responsive browsing of slow network shares.

## Open questions

- What about Finder bothers the user enough to replace it: appearance, speed, keyboard control or
  NAS handling? The answer sets what the first version prioritises.
- Which scope tier the first version targets.
- Minimum macOS version.
