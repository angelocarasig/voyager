//
//  FileOperations.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

enum FileOperationError: LocalizedError, Equatable {
    case invalidName
    case nameTaken(String)
    case pasteIntoItself
    case compressFailed

    var errorDescription: String? {
        switch self {
        case .invalidName: "Names can't be empty, start with a dot, or contain a slash or colon."
        case .nameTaken(let name): "An item named \"\(name)\" already exists here."
        case .pasteIntoItself: "A folder can't be pasted into itself."
        case .compressFailed: "The archive could not be created."
        }
    }
}

// runs off the main actor - copies and moves on the nas can take a while
enum FileOperations {
    static let newFolderName = "untitled folder"

    static func copyName(for url: URL, in folder: URL) -> URL {
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        return freeURL(in: folder, isDirectory: url.hasDirectoryPath) { index in
            let stem = index == 1 ? "\(base) copy" : "\(base) copy \(index)"

            return ext.isEmpty ? stem : "\(stem).\(ext)"
        }
    }

    static func newFolderURL(in folder: URL) -> URL {
        freeURL(in: folder, isDirectory: true) { index in
            index == 1 ? newFolderName : "\(newFolderName) \(index)"
        }
    }

    static func validate(name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, !trimmed.hasPrefix("."), !trimmed.contains("/"), !trimmed.contains(":") else {
            throw FileOperationError.invalidName
        }

        return trimmed
    }

    @concurrent
    static func duplicate(_ urls: [URL]) async throws -> [URL] {
        try urls.map { url in
            let copy = copyName(for: url, in: url.deletingLastPathComponent())
            try FileManager.default.copyItem(at: url, to: copy)

            return copy
        }
    }

    @concurrent
    static func rename(_ url: URL, to name: String) async throws -> URL {
        let name = try validate(name: name)
        let target = url.deletingLastPathComponent().appending(path: name, directoryHint: url.hasDirectoryPath ? .isDirectory : .notDirectory)

        guard target.lastPathComponent != url.lastPathComponent else { return url }

        // a case-only rename points at the same file on a case-insensitive disk, so it is not a clash
        let sameFile = target.path(percentEncoded: false).lowercased() == url.path(percentEncoded: false).lowercased()

        if !sameFile, FileManager.default.fileExists(atPath: target.path(percentEncoded: false)) {
            throw FileOperationError.nameTaken(name)
        }

        try FileManager.default.moveItem(at: url, to: target)

        return target
    }

    @concurrent
    static func trash(_ urls: [URL]) async throws -> [URL] {
        try urls.map { url in
            var landed: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &landed)

            return (landed as URL?) ?? url
        }
    }

    @concurrent
    static func newFolder(in folder: URL) async throws -> URL {
        let url = newFolderURL(in: folder)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)

        return url
    }

    @concurrent
    static func paste(_ urls: [URL], into folder: URL, move: Bool) async throws -> [URL] {
        let folderPath = folder.standardizedFileURL.path(percentEncoded: false)

        for url in urls where url.hasDirectoryPath {
            let path = url.standardizedFileURL.path(percentEncoded: false)

            if folderPath == path || folderPath.hasPrefix(path.hasSuffix("/") ? path : path + "/") {
                throw FileOperationError.pasteIntoItself
            }
        }

        return try urls.map { url in
            let direct = folder.appending(path: url.lastPathComponent, directoryHint: url.hasDirectoryPath ? .isDirectory : .notDirectory)

            if move, direct.standardizedFileURL == url.standardizedFileURL {
                return url
            }

            let target = FileManager.default.fileExists(atPath: direct.path(percentEncoded: false))
                ? copyName(for: url, in: folder)
                : direct

            if move {
                try FileManager.default.moveItem(at: url, to: target)
            } else {
                try FileManager.default.copyItem(at: url, to: target)
            }

            return target
        }
    }

    @concurrent
    static func compress(_ urls: [URL]) async throws -> URL {
        guard let first = urls.first else { throw FileOperationError.compressFailed }

        let folder = first.deletingLastPathComponent()
        let base = urls.count == 1 ? first.lastPathComponent : "Archive"
        let archive = freeURL(in: folder, isDirectory: false) { index in
            index == 1 ? "\(base).zip" : "\(base) \(index).zip"
        }

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/zip")
        process.currentDirectoryURL = folder
        process.arguments = ["-r", "-y", "-q", archive.lastPathComponent] + urls.map(\.lastPathComponent)

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { throw FileOperationError.compressFailed }

        return archive
    }

    private static func freeURL(in folder: URL, isDirectory: Bool, name: (Int) -> String) -> URL {
        var index = 1

        while true {
            let candidate = folder.appending(path: name(index), directoryHint: isDirectory ? .isDirectory : .notDirectory)

            if !FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
                return candidate
            }

            index += 1
        }
    }
}
