//
//  FileIcon.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileIcon: View {
    let item: FileItem
    let size: CGFloat

    @Environment(\.displayScale) private var scale
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if item.opensAsFolder {
                Image(systemName: "folder.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.userAccent)
                    .padding(size * 0.06)
            } else {
                Image(nsImage: thumbnail ?? Self.icon(for: item))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .task(id: item.id) {
                        thumbnail = nil
                        thumbnail = await Thumbnails.image(for: item.url, size: size, scale: scale)
                    }
            }
        }
        .frame(width: size, height: size)
    }

    // type icons never touch the file, so a row can draw before its thumbnail arrives;
    // packages are the exception because each app has its own icon
    private static func icon(for item: FileItem) -> NSImage {
        if item.isPackage {
            return NSWorkspace.shared.icon(forFile: item.url.path(percentEncoded: false))
        }

        return NSWorkspace.shared.icon(for: item.type ?? .data)
    }
}
