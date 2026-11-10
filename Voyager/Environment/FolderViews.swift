//
//  FolderViews.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import Observation

// folders that remember their own view, kept in one file under ~/.config so nothing is written into browsed folders
@MainActor
@Observable
final class FolderViews {
    static let shared = FolderViews(file: URL.homeDirectory.appending(path: ".config/voyager/folders.json"))

    private var entries: [String: FolderView]

    @ObservationIgnored private let file: URL

    init(file: URL) {
        self.file = file

        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true

        entries = (try? Data(contentsOf: file)).flatMap { try? decoder.decode([String: FolderView].self, from: $0) } ?? [:]
    }

    func view(for folder: URL) -> FolderView? {
        entries[folder.folderKey]
    }

    func set(_ view: FolderView, for folder: URL) {
        entries[folder.folderKey] = view
        save()
    }

    func remove(for folder: URL) {
        entries[folder.folderKey] = nil
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(entries).write(to: file, options: .atomic)
    }
}
