//
//  TempFolder.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

struct TempFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "voyagerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    @discardableResult
    func file(_ name: String, contents: String = "") throws -> URL {
        let file = url.appending(path: name)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: file)

        return file
    }

    @discardableResult
    func folder(_ name: String) throws -> URL {
        let folder = url.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        return folder
    }

    @discardableResult
    func link(_ name: String, to target: URL) throws -> URL {
        let link = url.appending(path: name)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        return link
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
