//
//  FileTable.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

struct FileTable: View {
    @Bindable var model: BrowserViewModel

    var body: some View {
        ScrollViewReader { proxy in
            Table(of: FileItem.self, selection: $model.selection, sortOrder: $model.sortOrder) {
                TableColumn("Name", value: \.name, comparator: .localizedStandard) { item in
                    HStack(spacing: 6) {
                        FileIcon(item: item, size: 16)
                        Text(item.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .width(min: 180, ideal: 340)

                TableColumn("Date Modified", sortUsing: KeyPathComparator(\FileItem.modified)) { item in
                    Text(item.modified?.formatted(date: .abbreviated, time: .shortened) ?? "--")
                        .foregroundStyle(.secondary)
                }
                .width(min: 120, ideal: 170)

                TableColumn("Size", sortUsing: KeyPathComparator(\FileItem.size)) { item in
                    Text(item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .width(min: 60, ideal: 80)

                TableColumn("Kind", value: \.kind) { item in
                    Text(item.kind)
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 140)
            } rows: {
                ForEach(model.items) { item in
                    TableRow(item)
                        .draggable(item.url)
                        .dropDestination(for: URL.self) { urls in
                            drop(urls, into: item.opensAsFolder ? item.url : model.current)
                        }
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                drop(urls, into: model.current)
                return true
            }
            .scrollContentBackground(.hidden)
            .alternatingRowBackgrounds(.disabled)
            .contextMenu(forSelectionType: FileItem.ID.self) { ids in
                FileContextMenu(items: model.items.filter { ids.contains($0.id) }, model: model)
            } primaryAction: { ids in
                Task { await model.open(ids) }
            }
            .onChange(of: model.selection) { _, selection in
                if selection.count == 1, let id = selection.first {
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private func drop(_ urls: [URL], into folder: URL) {
        Task { await model.drop(urls, into: folder) }
    }
}
