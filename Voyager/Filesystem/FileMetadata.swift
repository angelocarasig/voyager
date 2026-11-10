//
//  FileMetadata.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import CoreServices
import Foundation

struct FileMetadata: Sendable {
    let lastOpened: Date?
    let width: Int?
    let height: Int?
    let duration: Double?

    var dimensions: String? {
        guard let width, let height else { return nil }

        return "\(width) x \(height)"
    }

    var length: String? {
        guard let duration else { return nil }

        let total = Int(duration.rounded())
        let seconds = total % 60
        let minutes = (total / 60) % 60
        let hours = total / 3_600

        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

extension FileMetadata {
    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [URL: FileMetadata] = [:]

        subscript(url: URL) -> FileMetadata? {
            get { lock.withLock { values[url] } }
            set { lock.withLock { values[url] = newValue } }
        }
    }

    private static let cache = Cache()

    // spotlight reads can be slow on network volumes, so they never run on the main actor
    @concurrent
    static func load(_ url: URL) async -> FileMetadata {
        if let cached = cache[url] {
            return cached
        }

        let metadata = read(url)
        cache[url] = metadata

        return metadata
    }

    private static func read(_ url: URL) -> FileMetadata {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else {
            return FileMetadata(lastOpened: nil, width: nil, height: nil, duration: nil)
        }

        func value(_ key: CFString) -> Any? {
            MDItemCopyAttribute(item, key)
        }

        return FileMetadata(
            lastOpened: value(kMDItemLastUsedDate) as? Date,
            width: (value(kMDItemPixelWidth) as? NSNumber)?.intValue,
            height: (value(kMDItemPixelHeight) as? NSNumber)?.intValue,
            duration: (value(kMDItemDurationSeconds) as? NSNumber)?.doubleValue
        )
    }
}
