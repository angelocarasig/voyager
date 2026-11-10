//
//  FileClipboard.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit

// copy goes through the system pasteboard so finder can paste it; cut is voyager-only,
// because the pasteboard has no "cut" flag for files
@MainActor
final class FileClipboard {
    static let shared = FileClipboard(pasteboard: .general)

    private let pasteboard: NSPasteboard
    private var cutChangeCount: Int?

    init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
    }

    var urls: [URL] {
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])

        return (objects as? [URL]) ?? []
    }

    var isCut: Bool {
        cutChangeCount == pasteboard.changeCount
    }

    var canPaste: Bool {
        !urls.isEmpty
    }

    func copy(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        write(urls)
        cutChangeCount = nil
    }

    func cut(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        write(urls)
        cutChangeCount = pasteboard.changeCount
    }

    func copyPaths(_ urls: [URL]) {
        pasteboard.clearContents()
        pasteboard.setString(urls.map { $0.path(percentEncoded: false) }.joined(separator: "\n"), forType: .string)
        cutChangeCount = nil
    }

    // a cut is used up by its paste; a copy can be pasted again
    func didPaste() {
        guard isCut else { return }

        pasteboard.clearContents()
        cutChangeCount = nil
    }

    private func write(_ urls: [URL]) {
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }
}
