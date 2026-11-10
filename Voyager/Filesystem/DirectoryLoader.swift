//
//  DirectoryLoader.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation
import UniformTypeIdentifiers

enum DirectoryLoader {
    private static let keys: Set<URLResourceKey> = [
        .nameKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .creationDateKey,
        .isHiddenKey,
        .localizedTypeDescriptionKey,
        .contentTypeKey,
        .isDirectoryKey,
        .isPackageKey,
        .isSymbolicLinkKey,
        .addedToDirectoryDateKey,
        .tagNamesKey,
    ]

    // runs off the main actor - smb listings take seconds and must never stall the ui
    @concurrent
    static func load(_ folder: URL, showingHidden: Bool) async throws -> [FileItem] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: showingHidden ? [] : [.skipsHiddenFiles]
        )
        try Task.checkCancellation()

        return FileItem.arrange(urls.map(item), by: FileItem.defaultOrder)
    }

    static func item(at url: URL) -> FileItem {
        guard let own = try? url.resourceValues(forKeys: keys) else {
            return FileItem(
                url: url, name: url.lastPathComponent, size: nil, modified: nil, created: nil, kind: "",
                type: nil, isDirectory: false, isPackage: false, isHidden: url.lastPathComponent.hasPrefix(".")
            )
        }

        let values = own.isSymbolicLink == true
            ? (try? url.resolvingSymlinksInPath().resourceValues(forKeys: keys)) ?? own
            : own
        let isDirectory = values.isDirectory ?? false

        return FileItem(
            url: url,
            name: own.name ?? url.lastPathComponent,
            size: isDirectory ? nil : values.fileSize.map(Int64.init),
            modified: values.contentModificationDate,
            created: values.creationDate,
            kind: values.localizedTypeDescription ?? "",
            type: values.contentType,
            isDirectory: isDirectory,
            isPackage: values.isPackage ?? false,
            isHidden: own.isHidden == true || url.lastPathComponent.hasPrefix("."),
            dateAdded: values.addedToDirectoryDate,
            tags: values.tagNames ?? []
        )
    }
}
