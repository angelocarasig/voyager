//
//  FileTable.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

struct FileTable: View {
    @Bindable var model: BrowserViewModel
    @State private var columns = TableColumnCustomization<FileItem>()
    @AppStorage(Preferences.Key.tableColumns) private var storedColumns = Data()

    private var settings: ViewSettings { SettingsStore.shared.settings.view }

    var body: some View {
        ScrollViewReader { proxy in
            Table(of: FileItem.self, selection: $model.selection, sortOrder: $model.sortOrder, columnCustomization: $columns) {
                TableColumn("Name", value: \.name, comparator: .localizedStandard) { item in
                    HStack(spacing: 6) {
                        if settings.checkBoxes {
                            ItemCheckbox(isOn: model.selection.contains(item.id)) { model.toggleChecked(item) }
                        }

                        FileIcon(item: item, size: 16)

                        if model.renaming?.id == item.id {
                            RenameField(item: item, model: model)
                        } else {
                            Text(item.displayName(showingExtension: settings.showExtensions))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .opacity(item.isHidden ? 0.5 : 1)
                }
                .width(min: 180, ideal: 340)
                .customizationID("name")

                TableColumn("Date Modified", sortUsing: KeyPathComparator(\FileItem.modified)) { item in
                    cell(item, text: item.modified?.formatted(date: .abbreviated, time: .shortened))
                }
                .width(min: 120, ideal: 170)
                .customizationID("modified")

                TableColumn("Size", sortUsing: KeyPathComparator(\FileItem.size)) { item in
                    cell(item, text: item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) })
                        .monospacedDigit()
                }
                .width(min: 60, ideal: 80)
                .customizationID("size")

                TableColumn("Kind", value: \.kind, comparator: .localizedStandard) { item in
                    cell(item, text: item.kind)
                }
                .width(min: 80, ideal: 140)
                .customizationID("kind")

                TableColumn("Date Created", sortUsing: KeyPathComparator(\FileItem.created)) { item in
                    cell(item, text: item.created?.formatted(date: .abbreviated, time: .shortened))
                }
                .width(min: 120, ideal: 170)
                .customizationID("created")
                .defaultVisibility(.hidden)

                TableColumn("Date Added") { item in
                    cell(item, text: item.dateAdded?.formatted(date: .abbreviated, time: .shortened))
                }
                .width(min: 120, ideal: 170)
                .customizationID("dateAdded")
                .defaultVisibility(.hidden)

                TableColumn("Date Last Opened") { item in
                    MetadataCell(item: item) { $0.lastOpened?.formatted(date: .abbreviated, time: .shortened) }
                }
                .width(min: 120, ideal: 170)
                .customizationID("lastOpened")
                .defaultVisibility(.hidden)

                TableColumn("Tags") { item in
                    cell(item, text: item.tags.isEmpty ? nil : item.tags.joined(separator: ", "))
                }
                .width(min: 80, ideal: 140)
                .customizationID("tags")
                .defaultVisibility(.hidden)

                TableColumn("Dimensions") { item in
                    MetadataCell(item: item) { $0.dimensions }
                }
                .width(min: 80, ideal: 110)
                .customizationID("dimensions")
                .defaultVisibility(.hidden)

                TableColumn("Duration") { item in
                    MetadataCell(item: item) { $0.length }
                }
                .width(min: 60, ideal: 80)
                .customizationID("duration")
                .defaultVisibility(.hidden)
            } rows: {
                if model.view.group == .none {
                    ForEach(model.visibleItems, content: row)
                } else {
                    ForEach(model.groups) { group in
                        Section {
                            if !model.collapsedGroups.contains(group.id) {
                                ForEach(group.items, content: row)
                            }
                        } header: {
                            GroupHeader(group: group, isCollapsed: model.collapsedGroups.contains(group.id)) {
                                model.toggleGroup(group.id)
                            }
                        }
                    }
                }
            }
            .background(TableBand(rows: rowIDs, model: model, color: .userAccent))
            .environment(\.defaultMinListRowHeight, settings.compact ? 18 : 24)
            .dropDestination(for: URL.self) { urls, _ in
                drop(urls, into: model.current)
                return true
            }
            .scrollContentBackground(.hidden)
            .alternatingRowBackgrounds(.disabled)
            .contextMenu(forSelectionType: FileItem.ID.self) { ids in
                FileContextMenu(items: model.items.filter { ids.contains($0.id) }, model: model)
            } primaryAction: { ids in
                guard model.renaming == nil else { return }

                Task { await model.open(ids) }
            }
            .onChange(of: model.selection) { _, selection in
                if selection.count == 1, let id = selection.first {
                    proxy.scrollTo(id)
                }
            }
            .onAppear {
                if let saved = try? JSONDecoder().decode(TableColumnCustomization<FileItem>.self, from: storedColumns) {
                    columns = saved
                }
            }
            .onChange(of: columns) { _, columns in
                storedColumns = (try? JSONEncoder().encode(columns)) ?? Data()
            }
        }
    }

    private var rowIDs: [URL?] {
        guard model.view.group != .none else { return model.visibleItems.map(\.id) }

        return model.groups.flatMap { group in
            [nil] + (model.collapsedGroups.contains(group.id) ? [] : group.items.map(\.id))
        }
    }

    private func row(_ item: FileItem) -> some TableRowContent<FileItem> {
        TableRow(item)
            .draggable(item.url)
            .dropDestination(for: URL.self) { urls in
                drop(urls, into: item.opensAsFolder ? item.url : model.current)
            }
    }

    private func cell(_ item: FileItem, text: String?) -> some View {
        Text(text ?? "--")
            .foregroundStyle(.secondary)
            .opacity(item.isHidden ? 0.5 : 1)
    }

    private func drop(_ urls: [URL], into folder: URL) {
        Task { await model.drop(urls, into: folder) }
    }
}

private struct MetadataCell: View {
    let item: FileItem
    let text: (FileMetadata) -> String?
    @State private var metadata: FileMetadata?

    var body: some View {
        Text(metadata.flatMap(text) ?? "--")
            .foregroundStyle(.secondary)
            .opacity(item.isHidden ? 0.5 : 1)
            .task(id: item.id) {
                metadata = item.opensAsFolder ? nil : await FileMetadata.load(item.url)
            }
    }
}
