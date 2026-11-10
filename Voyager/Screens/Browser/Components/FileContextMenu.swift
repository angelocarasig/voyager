//
//  FileContextMenu.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileContextMenu: View {
    let items: [FileItem]
    let model: BrowserViewModel

    // empty space acts on the folder being shown
    private var targets: [URL] { items.isEmpty ? [model.current] : items.map(\.url) }

    var body: some View {
        let groups = FileAction.groups(for: items, isPinned: Pins.shared.contains, canPaste: FileClipboard.shared.canPaste)

        ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
            if index > 0 {
                Divider()
            }

            ForEach(group, id: \.self) { action in
                control(for: action)
            }
        }
        .labelStyle(.titleAndIcon)
    }

    @ViewBuilder
    private func control(for action: FileAction) -> some View {
        switch action {
        case .open:
            button(action, "Open") { Task { await model.open(Set(items.map(\.id))) } }
        case .openWith:
            openWithMenu
        case .openInTerminal:
            button(action, "Open in Terminal") { model.openInTerminal(targets[0]) }
        case .quickLook:
            button(action, "Quick Look") { model.previewURL = targets.first }
        case .cut:
            button(action, "Cut") { FileClipboard.shared.cut(targets) }
        case .copy:
            button(action, "Copy") { FileClipboard.shared.copy(targets) }
        case .paste:
            button(action, "Paste") { Task { await model.paste(into: targets[0]) } }
        case .duplicate:
            button(action, "Duplicate") { Task { await model.duplicate(targets) } }
        case .rename:
            button(action, "Rename…") { model.renaming = items.first }
        case .compress:
            button(action, items.count == 1 ? "Compress \"\(items[0].name)\"" : "Compress \(items.count) Items") {
                Task { await model.compress(targets) }
            }
        case .moveToTrash:
            button(action, "Move to Trash") { Task { await model.moveToTrash(targets) } }
        case .pin:
            button(action, "Pin to Sidebar") { Pins.shared.pin(targets) }
        case .unpin:
            button(action, "Unpin from Sidebar") { Pins.shared.unpin(targets) }
        case .copyPath:
            button(action, targets.count == 1 ? "Copy Path" : "Copy Paths") { FileClipboard.shared.copyPaths(targets) }
        case .showInFinder:
            button(action, "Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(targets) }
        case .newFolder:
            button(action, "New Folder") { Task { await model.newFolder() } }
        case .reload:
            button(action, "Reload") { Task { await model.reload() } }
        }
    }

    private func button(_ action: FileAction, _ title: String, perform: @escaping () -> Void) -> some View {
        Button(role: action == .moveToTrash ? .destructive : nil, action: perform) {
            // the destructive role alone does not tint a mac menu item
            if action == .moveToTrash {
                Label {
                    Text(title).foregroundStyle(.red)
                } icon: {
                    Image(systemName: action.symbol).foregroundStyle(.red)
                }
            } else {
                Label(title, systemImage: action.symbol)
            }
        }
        .keyboardShortcut(action.shortcut)
    }

    // apps are listed for the first item; every selected file opens in the chosen one
    @ViewBuilder
    private var openWithMenu: some View {
        let first = targets.first
        let apps = first.map(NSWorkspace.shared.urlsForApplications(toOpen:)) ?? []
        let defaultApp = first.flatMap(NSWorkspace.shared.urlForApplication(toOpen:))

        Menu("Open With", systemImage: FileAction.openWith.symbol) {
            ForEach(apps, id: \.self) { app in
                let name = FileManager.default.displayName(atPath: app.path(percentEncoded: false))

                Button {
                    open(with: app)
                } label: {
                    Label {
                        Text(app == defaultApp ? "\(name) (default)" : name)
                    } icon: {
                        Image(nsImage: Self.icon(for: app))
                    }
                }
            }

            if !apps.isEmpty {
                Divider()
            }

            Button("Choose Another App…", action: chooseApp)
        }
        .labelStyle(.titleAndIcon)
    }

    private func open(with app: URL) {
        NSWorkspace.shared.open(targets, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(filePath: "/Applications", directoryHint: .isDirectory)
        panel.allowedContentTypes = [.application]
        panel.prompt = "Open"
        panel.message = items.count == 1 ? "Choose an app to open \u{201C}\(items[0].name)\u{201D}." : "Choose an app to open \(items.count) items."

        guard panel.runModal() == .OK, let app = panel.url else { return }

        open(with: app)
    }

    // menus draw images at their own size, so the 32pt app icon is scaled to a menu icon
    private static func icon(for app: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: app.path(percentEncoded: false))
        icon.size = NSSize(width: 16, height: 16)

        return icon
    }
}
