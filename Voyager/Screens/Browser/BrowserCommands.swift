//
//  BrowserCommands.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI

struct BrowserCommands: Commands {
    @FocusedValue(\.browser) private var browser
    @AppStorage(Preferences.Key.viewMode) private var viewMode: ViewMode = .list

    private var selected: [URL] { browser?.selectedItems.map(\.url) ?? [] }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Folder", systemImage: FileAction.newFolder.symbol) { file { await $0.newFolder() } }
                .keyboardShortcut(FileAction.newFolder.shortcut)
                .disabled(browser == nil)

            Divider()

            Button("Quick Look", systemImage: FileAction.quickLook.symbol) { file { $0.previewURL = $0.selectedItems.first?.url } }
                .keyboardShortcut(FileAction.quickLook.shortcut)
                .disabled(selected.isEmpty)

            Button("Duplicate", systemImage: FileAction.duplicate.symbol) { file { await $0.duplicate($0.selectedItems.map(\.url)) } }
                .keyboardShortcut(FileAction.duplicate.shortcut)
                .disabled(selected.isEmpty)

            Button("Move to Trash", systemImage: FileAction.moveToTrash.symbol, role: .destructive) {
                file(forwarding: #selector(NSResponder.deleteToBeginningOfLine(_:))) { await $0.moveToTrash($0.selectedItems.map(\.url)) }
            }
            .keyboardShortcut(FileAction.moveToTrash.shortcut)
            .disabled(selected.isEmpty)

            Divider()

            pinButton

            Button(selected.count > 1 ? "Copy Paths" : "Copy Path", systemImage: FileAction.copyPath.symbol) {
                file { FileClipboard.shared.copyPaths($0.selectedItems.isEmpty ? [$0.current] : $0.selectedItems.map(\.url)) }
            }
            .keyboardShortcut(FileAction.copyPath.shortcut)
            .disabled(browser == nil)
        }

        // the system's cut, copy and paste still reach text fields; files take them otherwise
        CommandGroup(replacing: .pasteboard) {
            Button("Cut", systemImage: FileAction.cut.symbol) {
                file(forwarding: #selector(NSText.cut(_:))) { FileClipboard.shared.cut($0.selectedItems.map(\.url)) }
            }
            .keyboardShortcut(FileAction.cut.shortcut)

            Button("Copy", systemImage: FileAction.copy.symbol) {
                file(forwarding: #selector(NSText.copy(_:))) { FileClipboard.shared.copy($0.selectedItems.map(\.url)) }
            }
            .keyboardShortcut(FileAction.copy.shortcut)

            Button("Paste", systemImage: FileAction.paste.symbol) {
                file(forwarding: #selector(NSText.paste(_:))) { await $0.paste(into: $0.current) }
            }
            .keyboardShortcut(FileAction.paste.shortcut)

            Button("Select All") {
                file(forwarding: #selector(NSText.selectAll(_:))) { $0.selection = Set($0.items.map(\.id)) }
            }
            .keyboardShortcut("a")
        }

        CommandGroup(before: .toolbar) {
            Picker("View", selection: $viewMode) {
                Text("as List").tag(ViewMode.list)
                    .keyboardShortcut("1")
                Text("as Icons").tag(ViewMode.grid)
                    .keyboardShortcut("2")
            }
            .pickerStyle(.inline)
            .labelsHidden()

            Divider()
        }

        CommandMenu("Go") {
            Button("Back") { run { await $0.goBack() } }
                .keyboardShortcut("[")
                .disabled(browser?.canGoBack != true)

            Button("Forward") { run { await $0.goForward() } }
                .keyboardShortcut("]")
                .disabled(browser?.canGoForward != true)

            Button("Enclosing Folder") { run { await $0.goUp() } }
                .keyboardShortcut(.upArrow)
                .disabled(browser?.canGoUp != true)

            Button("Open") { run { await $0.open($0.selection) } }
                .keyboardShortcut(.downArrow)
                .disabled(browser?.selection.isEmpty != false)

            Divider()

            Button("Go to Folder…") { browser?.isEditingPath = true }
                .keyboardShortcut("l")
                .disabled(browser == nil)

            Button("Reload") { run { await $0.reload() } }
                .keyboardShortcut("r")
                .disabled(browser == nil)
        }
    }

    @ViewBuilder
    private var pinButton: some View {
        let folders = browser?.selectedItems.filter(\.opensAsFolder).map(\.url) ?? []
        let isPinned = !folders.isEmpty && folders.allSatisfy(Pins.shared.contains)
        let action: FileAction = isPinned ? .unpin : .pin

        Button(isPinned ? "Unpin from Sidebar" : "Pin to Sidebar", systemImage: action.symbol) {
            file { _ in isPinned ? Pins.shared.unpin(folders) : Pins.shared.pin(folders) }
        }
        .keyboardShortcut(action.shortcut)
        .disabled(folders.isEmpty || folders.count != selected.count)
    }

    // a focused text field gets the key's text meaning instead, so typing a path never trashes files
    private func file(forwarding selector: Selector? = nil, _ action: @escaping @MainActor (BrowserViewModel) async -> Void) {
        guard let browser, !(NSApp.keyWindow?.firstResponder is NSText) else {
            if let selector {
                NSApp.sendAction(selector, to: nil, from: nil)
            }

            return
        }

        Task { await action(browser) }
    }

    private func run(_ action: @escaping @MainActor (BrowserViewModel) async -> Void) {
        guard let browser else { return }

        Task { await action(browser) }
    }
}
