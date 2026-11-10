//
//  DetailsPane.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct DetailsPane: View {
    let model: BrowserViewModel

    @State private var metadata: FileMetadata?
    @State private var folder: FileItem?

    var body: some View {
        let items = model.selectedItems

        ScrollView {
            if items.count > 1 {
                summary(items)
            } else if let item = items.first ?? folder {
                single(item)
            }
        }
        .font(SettingsStore.shared.settings.font())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: model.current) {
            folder = await Self.folderItem(model.current)
        }
    }

    @concurrent
    private static func folderItem(_ url: URL) async -> FileItem {
        DirectoryLoader.item(at: url)
    }

    private func summary(_ items: [FileItem]) -> some View {
        let total = items.reduce(Int64(0)) { $0 + ($1.size ?? 0) }

        return VStack(spacing: 6) {
            Text("\(items.count) items selected")

            Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    private func single(_ item: FileItem) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                FileIcon(item: item, size: 128)
                    .opacity(item.isHidden ? 0.5 : 1)

                Text(item.name)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                Text(item.kind)
                    .foregroundStyle(Color.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows(for: item), id: \.0) { row in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.0)
                            .font(SettingsStore.shared.settings.font(scale: 0.85))
                            .foregroundStyle(Color.secondary)

                        Text(row.1)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .task(id: item.url) {
            metadata = nil
            metadata = await FileMetadata.load(item.url)
        }
    }

    private func rows(for item: FileItem) -> [(String, String)] {
        var rows: [(String, String?)] = [
            ("Size", item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }),
            ("Date modified", item.modified.map(Self.format)),
            ("Date created", item.created.map(Self.format)),
            ("Date added", item.dateAdded.map(Self.format)),
            ("Date last opened", metadata?.lastOpened.map(Self.format)),
            ("Dimensions", metadata?.dimensions),
            ("Duration", metadata?.length),
            ("Tags", item.tags.isEmpty ? nil : item.tags.joined(separator: ", ")),
        ]

        rows.append(("Where", item.url.deletingLastPathComponent().path(percentEncoded: false)))

        return rows.compactMap { row in row.1.map { (row.0, $0) } }
    }

    private static func format(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
