//
//  BrowserViewModel.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class BrowserViewModel {
    typealias Loader = @Sendable (URL, Bool) async throws -> [FileItem]

    private let load: Loader
    private let clipboard: FileClipboard

    private(set) var current: URL
    private(set) var items: [FileItem] = []
    private(set) var itemsFolder: URL?
    private(set) var isLoading = false
    private(set) var failure: String?
    private(set) var backStack: [URL] = []
    private(set) var forwardStack: [URL] = []

    var selection: Set<FileItem.ID> = []
    var isEditingPath = false
    var previewURL: URL?
    var renaming: FileItem?
    var extensionChange: ExtensionChange?
    var operationFailure: String?

    var collapsedGroups: Set<String> = []

    @ObservationIgnored private var loading: Task<Void, Never>?

    var isSwitching: Bool { isLoading && itemsFolder != current }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var canGoUp: Bool { current.path(percentEncoded: false) != "/" }

    var selectedItems: [FileItem] {
        items.filter { selection.contains($0.id) }
    }

    var view: FolderView {
        FolderViews.shared.view(for: current) ?? SettingsStore.shared.settings.view.folder
    }

    var remembersView: Bool {
        get { FolderViews.shared.view(for: current) != nil }
        set {
            if newValue {
                FolderViews.shared.set(view, for: current)
            } else {
                FolderViews.shared.remove(for: current)
            }
        }
    }

    var sortOrder: [KeyPathComparator<FileItem>] {
        get { [view.sort.comparator(ascending: view.ascending)] }
        set {
            guard let first = newValue.first, let field = SortField(first) else { return }

            updateView {
                $0.sort = field
                $0.ascending = first.order == .forward
            }
        }
    }

    var groups: [FileGroup] {
        fileGroups(items, by: view.group)
    }

    var visibleItems: [FileItem] {
        groups.filter { !collapsedGroups.contains($0.id) }.flatMap(\.items)
    }

    init(start: URL, load: @escaping Loader = DirectoryLoader.load, clipboard: FileClipboard = .shared) {
        self.current = Self.normalised(start)
        self.load = load
        self.clipboard = clipboard
    }

    func updateView(_ change: (inout FolderView) -> Void) {
        let before = view

        if FolderViews.shared.view(for: current) != nil {
            var entry = before
            change(&entry)
            FolderViews.shared.set(entry, for: current)
        } else {
            change(&SettingsStore.shared.settings.view.folder)
            SettingsStore.shared.save()
        }

        if view.sort != before.sort || view.ascending != before.ascending {
            rearrange()
        }
    }

    func setLayout(_ layout: ViewLayout) {
        updateView {
            $0.layout = layout

            if layout.isZoomable {
                $0.iconSize = layout.defaultIconSize
            }
        }
    }

    func rearrange() {
        items = FileItem.arrange(items, by: sortOrder)
    }

    func toggleGroup(_ id: String) {
        if collapsedGroups.contains(id) {
            collapsedGroups.remove(id)
        } else {
            collapsedGroups.insert(id)
        }
    }

    func toggleChecked(_ item: FileItem) {
        if selection.contains(item.id) {
            selection.remove(item.id)
        } else {
            selection.insert(item.id)
        }
    }

    func zoom(by steps: Int) {
        guard steps != 0 else { return }

        let factor = pow(1.12, Double(abs(steps)))

        updateView { view in
            switch view.layout {
            case .extraLargeIcons, .largeIcons, .mediumIcons:
                let size = steps > 0 ? view.iconSize * factor : view.iconSize / factor

                if size < 32 {
                    view.layout = .smallIcons
                    return
                }

                view.iconSize = min(size, 256)
                view.layout = view.iconSize < 80 ? .mediumIcons : view.iconSize < 176 ? .largeIcons : .extraLargeIcons
            case .smallIcons:
                if steps > 0 {
                    view.layout = .mediumIcons
                    view.iconSize = 48
                } else {
                    view.layout = .list
                }
            case .list:
                view.layout = steps > 0 ? .smallIcons : .details
            case .details:
                if steps > 0 {
                    view.layout = .list
                }
            case .tiles, .content:
                break
            }
        }
    }

    func navigate(to folder: URL) async {
        let folder = Self.normalised(folder)

        guard folder != current else {
            await reload()
            return
        }

        backStack.append(current)
        forwardStack.removeAll()

        await show(folder)
    }

    func reveal(_ urls: [URL]) async {
        guard let first = urls.first else { return }

        guard !isFolder(first) else {
            await navigate(to: first)
            return
        }

        let keys = Set(urls.map(\.folderKey))

        await navigate(to: first.deletingLastPathComponent())
        selection = Set(items.filter { keys.contains($0.url.folderKey) }.map(\.id))
    }

    func goBack() async {
        guard let previous = backStack.popLast() else { return }

        forwardStack.append(current)

        await show(previous)
    }

    func goForward() async {
        guard let next = forwardStack.popLast() else { return }

        backStack.append(current)

        await show(next)
    }

    func goUp() async {
        guard canGoUp else { return }

        await navigate(to: current.deletingLastPathComponent())
    }

    func reload() async {
        await show(current)
    }

    func open(_ item: FileItem) async {
        if item.opensAsFolder {
            await navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func open(_ ids: Set<FileItem.ID>) async {
        let chosen = items.filter { ids.contains($0.id) }

        if chosen.count == 1, let only = chosen.first {
            await open(only)
            return
        }

        for item in chosen where !item.opensAsFolder {
            NSWorkspace.shared.open(item.url)
        }
    }

    func duplicate(_ urls: [URL]) async {
        await perform {
            let copies = try await FileOperations.duplicate(urls)
            Self.record(created: copies, "Duplicate")

            return copies
        }
    }

    func moveToTrash(_ urls: [URL]) async {
        await perform {
            let trashed = try await FileOperations.trash(urls)
            Self.record(moved: urls, to: trashed, "Move to Trash")

            return []
        }
    }

    func drop(_ urls: [URL], into folder: URL) async {
        let urls = urls.filter { $0.folderKey != folder.folderKey }

        guard !urls.isEmpty else { return }

        let volume = Self.volume(of: folder)
        let copy = NSEvent.modifierFlags.contains(.option) || urls.contains { Self.volume(of: $0) != volume }

        await perform { try await Self.paste(urls, into: folder, move: !copy) }
    }

    func compress(_ urls: [URL]) async {
        await perform {
            let archive = try await FileOperations.compress(urls)
            Self.record(created: [archive], "Compress")

            return [archive]
        }
    }

    func rename(_ item: FileItem, to name: String) async {
        await perform {
            let renamed = try await FileOperations.rename(item.url, to: name)
            Self.record(moved: [item.url], to: [renamed], "Rename")

            return [renamed]
        }
    }

    func commitRename(_ item: FileItem, to typed: String) async {
        renaming = nil

        let typed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = item.displayName(showingExtension: SettingsStore.shared.settings.view.showExtensions)

        guard typed != shown else { return }

        let old = Self.renameExtension(of: item.name, isFolder: item.opensAsFolder)
        let new = Self.renameExtension(of: typed, isFolder: item.opensAsFolder)

        if old.isEmpty || new.caseInsensitiveCompare(old) == .orderedSame {
            await rename(item, to: typed)
        } else if new.isEmpty {
            await rename(item, to: "\(typed).\(old)")
        } else {
            extensionChange = ExtensionChange(item: item, name: typed, oldExtension: old, newExtension: new)
        }
    }

    func apply(_ change: ExtensionChange, keepingOld: Bool) async {
        let name = keepingOld ? "\((change.name as NSString).deletingPathExtension).\(change.oldExtension)" : change.name

        await rename(change.item, to: name)
    }

    // folders, dotfiles and a "dot" followed by words, as in "Dr. Smith", have no extension
    static func renameExtension(of name: String, isFolder: Bool) -> String {
        let ext = (name as NSString).pathExtension

        guard !isFolder, !(name as NSString).deletingPathExtension.isEmpty, !ext.contains(" ") else { return "" }

        return ext
    }

    func newFolder() async {
        let folder = current

        await perform {
            let created = try await FileOperations.newFolder(in: folder)
            Self.record(created: [created], "New Folder")

            return [created]
        }

        renaming = selectedItems.count == 1 ? selectedItems.first : nil
    }

    func paste(into folder: URL) async {
        let urls = clipboard.urls
        let move = clipboard.isCut

        guard !urls.isEmpty else { return }

        let pasted = await perform { try await Self.paste(urls, into: folder, move: move) }

        if pasted, move {
            clipboard.didPaste()
        }
    }

    func openInTerminal(_ folder: URL) {
        let workspace = NSWorkspace.shared
        let terminal = workspace.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty")
            ?? workspace.urlForApplication(withBundleIdentifier: "com.apple.Terminal")

        guard let terminal else { return }

        workspace.open([folder], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }

    private static func paste(_ urls: [URL], into folder: URL, move: Bool) async throws -> [URL] {
        let pasted = try await FileOperations.paste(urls, into: folder, move: move)

        if move {
            record(moved: urls, to: pasted, "Move")
        } else {
            record(created: pasted, "Copy")
        }

        return pasted
    }

    private static func record(created urls: [URL], _ verb: String) {
        guard !urls.isEmpty else { return }

        FileHistory.shared.record(.trash(urls, permanently: false), named: FileHistory.name(verb, count: urls.count))
    }

    private static func record(moved originals: [URL], to results: [URL], _ verb: String) {
        let moves = zip(results, originals)
            .filter { $0.folderKey != $1.folderKey }
            .map { Relocation(from: $0, to: $1) }

        guard !moves.isEmpty else { return }

        FileHistory.shared.record(.move(moves), named: FileHistory.name(verb, count: moves.count))
    }

    @discardableResult
    private func perform(_ operation: () async throws -> [URL]) async -> Bool {
        do {
            let produced = Set(try await operation().map(\.folderKey))

            await reload()
            selection = Set(items.filter { produced.contains($0.url.folderKey) }.map(\.id))

            return true
        } catch {
            operationFailure = error.localizedDescription
            await reload()

            return false
        }
    }

    private func show(_ folder: URL) async {
        loading?.cancel()

        if folder != current {
            selection = []
        }

        current = folder
        failure = nil
        isLoading = true

        let showingHidden = SettingsStore.shared.settings.view.showHidden

        let task = Task { [load] in
            do {
                let listed = try await load(folder, showingHidden)
                guard !Task.isCancelled, current == folder else { return }

                if itemsFolder != folder {
                    collapsedGroups = []
                }

                items = FileItem.arrange(listed, by: sortOrder)
                itemsFolder = folder
                selection = selection.intersection(items.map(\.id))
                isLoading = false
            } catch {
                guard !Task.isCancelled, current == folder else { return }

                items = []
                itemsFolder = folder
                selection = []
                failure = Self.describe(error, opening: folder)
                isLoading = false
            }
        }
        loading = task

        await task.value
    }

    // foundation's own messages call every folder a file
    private static func describe(_ error: Error, opening folder: URL) -> String {
        let name = "\u{201C}\(folder.lastPathComponent)\u{201D}"

        switch (error as? CocoaError)?.code {
        case .fileReadNoPermission?:
            return "Voyager doesn\u{2019}t have permission to open \(name)."
        case .fileReadNoSuchFile?:
            return "\(name) no longer exists."
        default:
            let reason = ((error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError)?.localizedDescription

            return reason.map { "\(name) could not be read: \($0)." } ?? "\(name) could not be read."
        }
    }

    private static func volume(of url: URL) -> URL? {
        try? url.resourceValues(forKeys: [.volumeURLKey]).volume
    }

    private static func normalised(_ url: URL) -> URL {
        URL(filePath: url.standardizedFileURL.path(percentEncoded: false), directoryHint: .isDirectory)
    }
}

struct ExtensionChange {
    let item: FileItem
    let name: String
    let oldExtension: String
    let newExtension: String
}
