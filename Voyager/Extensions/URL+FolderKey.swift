//
//  URL+FolderKey.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Foundation

extension URL {
    // folder urls differ by a trailing slash depending on where they came from
    var folderKey: String {
        let path = standardizedFileURL.path(percentEncoded: false)

        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}
