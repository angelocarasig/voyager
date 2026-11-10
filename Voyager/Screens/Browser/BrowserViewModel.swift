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
    typealias Loader = @Sendable (URL) async throws -> [FileItem]

    private let load: Loader
    private let clipboard: FileClipboard

    private(set) var current: URL
    private(set) var items: [FileItem] = []
    private(set) var isLoading = false
    private(set) var failure: String?
    private(set) var backStack: [URL] = []
    private(set) var forwardStack: [URL] = []

    var selection: Set<FileItem.ID> = []
    var isEditingPath = false
    var previewURL: URL?
    var renaming: FileItem?
    var operationFailure: String?

    var sortOrder = FileItem.defaultOrder {
        didSet { items = FileItem.arrange(items, by: sortOrder) }
    }

    @ObservationIgnored private var loading: Task<Void, Never>?

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var canGoUp: Bool { current.path(percentEncoded: false) != "/" }

    var selectedItems: [FileItem] {
        items.filter { selection.contains($0.id) }
    }

    init(start: URL, load: @escaping Loader = DirectoryLoader.load, clipboard: FileClipboard = .shared) {
        self.current = Self.normalised(start)
        self.load = load
        self.clipboard = clipboard
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

    // a folder opens; files open their folder with them selected, the way finder reveals them
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

    // one folder navigates; several items open only the files, as finder does
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
        await perform { try await FileOperations.duplicate(urls) }
    }

    func moveToTrash(_ urls: [URL]) async {
        await perform {
            try await FileOperations.trash(urls)
            return []
        }
    }

    // option copies, and so does a drop onto another volume, as in finder
    func drop(_ urls: [URL], into folder: URL) async {
        let urls = urls.filter { $0.folderKey != folder.folderKey }

        guard !urls.isEmpty else { return }

        let volume = Self.volume(of: folder)
        let copy = NSEvent.modifierFlags.contains(.option) || urls.contains { Self.volume(of: $0) != volume }

        await perform { try await FileOperations.paste(urls, into: folder, move: !copy) }
    }

    func compress(_ urls: [URL]) async {
        await perform { [try await FileOperations.compress(urls)] }
    }

    func rename(_ item: FileItem, to name: String) async {
        await perform { [try await FileOperations.rename(item.url, to: name)] }
    }

    // finder starts a new folder in rename, so the name can be typed straight away
    func newFolder() async {
        let folder = current

        await perform { [try await FileOperations.newFolder(in: folder)] }

        renaming = selectedItems.count == 1 ? selectedItems.first : nil
    }

    func paste(into folder: URL) async {
        let urls = clipboard.urls
        let move = clipboard.isCut

        guard !urls.isEmpty else { return }

        let pasted = await perform { try await FileOperations.paste(urls, into: folder, move: move) }

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

    // reloads the folder, then selects whatever the operation produced
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

        // a reload keeps the old rows on screen until the new ones arrive
        if folder != current {
            items = []
            selection = []
        }

        current = folder
        failure = nil
        isLoading = true

        let task = Task { [load] in
            do {
                let listed = try await load(folder)
                guard !Task.isCancelled, current == folder else { return }

                items = FileItem.arrange(listed, by: sortOrder)
                selection = selection.intersection(items.map(\.id))
                isLoading = false
            } catch {
                guard !Task.isCancelled, current == folder else { return }

                items = []
                selection = []
                failure = error.localizedDescription
                isLoading = false
            }
        }
        loading = task

        await task.value
    }

    private static func volume(of url: URL) -> URL? {
        try? url.resourceValues(forKeys: [.volumeURLKey]).volume
    }

    private static func normalised(_ url: URL) -> URL {
        URL(filePath: url.standardizedFileURL.path(percentEncoded: false), directoryHint: .isDirectory)
    }
}
