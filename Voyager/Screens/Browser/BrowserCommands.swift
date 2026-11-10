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

            Button("Rename\u{2026}", systemImage: FileAction.rename.symbol) { file { $0.renaming = $0.selectedItems.first } }
                .keyboardShortcut(FileAction.rename.shortcut)
                .disabled(selected.count != 1)

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

        CommandGroup(replacing: .undoRedo) {
            Button(FileHistory.shared.undoTitle) {
                file(forwarding: Selector(("undo:"))) { _ in await FileHistory.shared.undo() }
            }
            .keyboardShortcut("z")

            Button(FileHistory.shared.redoTitle) {
                file(forwarding: Selector(("redo:"))) { _ in await FileHistory.shared.redo() }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }

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
            Picker("Layout", selection: Binding { browser?.view.layout ?? .details } set: { browser?.setLayout($0) }) {
                ForEach(ViewLayout.allCases) { layout in
                    Text(layout.title).tag(layout)
                        .keyboardShortcut(layout.shortcut)
                }
            }
            .pickerStyle(.inline)
            .disabled(browser == nil)

            Divider()

            Menu("Show") {
                showToggle("Compact view", \.compact)
                showToggle("Item check boxes", \.checkBoxes)
                showToggle("File name extensions", \.showExtensions)
                showToggle("Hidden items", \.showHidden)
                showToggle("Preview pane", \.previewPane) { if $0 { SettingsStore.shared.settings.view.detailsPane = false } }
                showToggle("Details pane", \.detailsPane) { if $0 { SettingsStore.shared.settings.view.previewPane = false } }
            }

            Toggle("Remember view for this folder", isOn: Binding { browser?.remembersView ?? false } set: { browser?.remembersView = $0 })
                .disabled(browser == nil)

            Menu("Sort by") {
                Picker("Sort by", selection: Binding { browser?.view.sort ?? .name } set: { field in browser?.updateView { $0.sort = field } }) {
                    ForEach(SortField.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)

                Divider()

                Picker("Order", selection: Binding { browser?.view.ascending ?? true } set: { ascending in browser?.updateView { $0.ascending = ascending } }) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
                .pickerStyle(.inline)
            }
            .disabled(browser == nil)

            Menu("Group by") {
                Picker("Group by", selection: Binding { browser?.view.group ?? .none } set: { field in browser?.updateView { $0.group = field } }) {
                    ForEach(GroupField.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            }
            .disabled(browser == nil)

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

    private func showToggle(_ title: String, _ keyPath: WritableKeyPath<ViewSettings, Bool>, onEnable: @escaping (Bool) -> Void = { _ in }) -> some View {
        Toggle(title, isOn: Binding {
            SettingsStore.shared.settings.view[keyPath: keyPath]
        } set: {
            SettingsStore.shared.settings.view[keyPath: keyPath] = $0
            onEnable($0)
            SettingsStore.shared.save()
        })
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
