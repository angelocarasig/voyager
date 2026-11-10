//
//  Thumbnails.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import QuickLookThumbnailing

enum Thumbnails {
    // nscache is thread-safe; it only lacks the sendable annotation
    nonisolated(unsafe) private static let cache = NSCache<NSString, NSImage>()

    // nil when the file has no real thumbnail, so callers keep the type icon
    static func image(for url: URL, size: CGFloat, scale: CGFloat) async -> NSImage? {
        let key = "\(url.path(percentEncoded: false))#\(Int(size * scale))" as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        nonisolated(unsafe) let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size, height: size),
            scale: scale,
            representationTypes: .thumbnail
        )

        let image = await withTaskCancellationHandler {
            try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        } onCancel: {
            QLThumbnailGenerator.shared.cancel(request)
        }

        if let image {
            cache.setObject(image, forKey: key)
        }

        return image
    }
}
