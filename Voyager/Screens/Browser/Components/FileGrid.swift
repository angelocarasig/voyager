//
//  FileGrid.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI

struct FileGrid: View {
    @Bindable var model: BrowserViewModel

    @State private var viewport = CGSize.zero
    @State private var tracking = GridTracking()
    @State private var band: CGRect?
    @State private var bandBase: Set<FileItem.ID>?
    @State private var anchor: FileItem.ID?
    @State private var dropTarget: FileItem.ID?

    private let space = "grid"
    private let viewportSpace = "viewport"
    private let checkboxInset: CGFloat = 24

    private var layout: ViewLayout { model.view.layout }
    private var compact: Bool { SettingsStore.shared.settings.view.compact }
    private var checkBoxes: Bool { SettingsStore.shared.settings.view.checkBoxes }
    private var spacing: CGFloat { compact ? 6 : 12 }
    private var padding: CGFloat { compact ? 8 : 16 }

    private var cellWidth: CGFloat {
        switch layout {
        case .smallIcons: 220
        case .list: 200
        case .tiles: 260
        default: model.view.iconSize + 40
        }
    }

    private var rowHeight: CGFloat { compact ? 22 : 28 }

    private var columns: Int {
        layout == .content ? 1 : max(1, Int((viewport.width - padding * 2 + spacing) / (cellWidth + spacing)))
    }

    private var rows: Int {
        max(1, Int((viewport.height - padding * 2 + spacing) / (rowHeight + spacing)))
    }

    private var gridColumns: [GridItem] {
        if layout == .content {
            return [GridItem(.flexible(), spacing: 0)]
        }

        return Array(repeating: GridItem(.fixed(cellWidth), spacing: spacing, alignment: .top), count: columns)
    }

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if layout == .list {
                    ScrollView(.horizontal) {
                        scaffold {
                            LazyHGrid(
                                rows: Array(repeating: GridItem(.fixed(rowHeight), spacing: spacing), count: rows),
                                spacing: spacing
                            ) {
                                ForEach(model.visibleItems) { item in
                                    cell(for: item)
                                }
                            }
                        }
                    }
                } else {
                    ScrollView {
                        scaffold {
                            LazyVStack(alignment: .leading, spacing: spacing) {
                                ForEach(model.groups) { group in
                                    section(group)
                                }
                            }
                        }
                    }
                }
            }
            .coordinateSpace(.named(viewportSpace))
            .onGeometryChange(for: CGSize.self) { geometry in
                geometry.size
            } action: { size in
                viewport = size
            }
            .onChange(of: layout) {
                tracking.frames = [:]
            }
            .background(MouseButtons(actions: [MouseButtons.secondary: selectForMenu]))
            .dragContainer(for: URL.self, itemID: \.self) { ids in ids }
            .dragContainerSelection(Array(model.selection))
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                guard press.modifiers.isEmpty else { return .ignored }

                move(by: offset(for: press.key))

                if let id = model.selection.first {
                    proxy.scrollTo(id)
                }

                return .handled
            }
        }
    }

    private func scaffold(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(padding)
            // a minimum taken from the measured viewport only ever grows, so it is set on the scrolling axis alone
            .frame(
                minWidth: layout == .list ? viewport.width : nil,
                maxWidth: layout == .list ? nil : .infinity,
                minHeight: layout == .list ? nil : viewport.height,
                maxHeight: layout == .list ? .infinity : nil,
                alignment: .topLeading
            )
            .background { surface }
            .overlay(alignment: .topLeading) { selectionBand }
            .coordinateSpace(.named(space))
            .onGeometryChange(for: CGPoint.self) { geometry in
                geometry.frame(in: .named(viewportSpace)).origin
            } action: { origin in
                tracking.contentOrigin = origin
            }
    }

    @ViewBuilder
    private func section(_ group: FileGroup) -> some View {
        let collapsed = model.collapsedGroups.contains(group.id)

        if model.view.group != .none {
            GroupHeader(group: group, isCollapsed: collapsed) {
                model.toggleGroup(group.id)
            }
        }

        if !collapsed {
            LazyVGrid(columns: gridColumns, spacing: layout == .content ? 0 : spacing) {
                ForEach(group.items) { item in
                    cell(for: item)
                }
            }
        }
    }

    private func cell(for item: FileItem) -> some View {
        let rowStyle = layout != .extraLargeIcons && layout != .largeIcons && layout != .mediumIcons

        return FileGridCell(
            item: item,
            layout: layout,
            iconSize: model.view.iconSize,
            compact: compact,
            leadingInset: checkBoxes && rowStyle ? checkboxInset : 0,
            isSelected: model.selection.contains(item.id),
            isDropTarget: dropTarget == item.id,
            rename: model.renaming?.id == item.id ? RenameField(item: item, model: model) : nil
        )
        .onGeometryChange(for: CGRect.self) { geometry in
            geometry.frame(in: .named(space))
        } action: { frame in
            tracking.frames[item.id] = frame
        }
        .frame(width: layout == .list ? cellWidth : nil, height: layout == .list ? rowHeight : nil)
        .frame(maxWidth: layout == .list ? nil : .infinity)
        .id(item.id)
        .onTapGesture(count: 2) {
            // a double-click inside the rename field selects a word instead
            guard model.renaming?.id != item.id else { return }

            Task { await model.open(item) }
        }
        .simultaneousGesture(TapGesture().onEnded { select(item) })
        .draggable(containerItemID: item.id)
        .dropDestination(for: URL.self) { urls, _ in
            Task { await model.drop(urls, into: item.opensAsFolder ? item.url : model.current) }
            return true
        } isTargeted: { targeted in
            if targeted {
                dropTarget = item.opensAsFolder ? item.id : nil
            } else if dropTarget == item.id {
                dropTarget = nil
            }
        }
        .contextMenu { FileContextMenu(items: targets(for: item), model: model) }
        .overlay(alignment: rowStyle ? .leading : .topLeading) {
            if checkBoxes {
                ItemCheckbox(isOn: model.selection.contains(item.id)) {
                    model.toggleChecked(item)
                }
                .padding(.leading, rowStyle ? 6 : max(2, (cellWidth - model.view.iconSize) / 2 - 4))
                .padding(.top, rowStyle ? 0 : 2)
            }
        }
    }

    private var surface: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(bandGesture)
            .contextMenu { FileContextMenu(items: [], model: model) }
            .dropDestination(for: URL.self) { urls, _ in
                Task { await model.drop(urls, into: model.current) }
                return true
            }
    }

    @ViewBuilder
    private var selectionBand: some View {
        if let band, band.width > 1 || band.height > 1 {
            Rectangle()
                .fill(Color.userAccent.opacity(0.15))
                .strokeBorder(Color.userAccent.opacity(0.6))
                .frame(width: band.width, height: band.height)
                .offset(x: band.minX, y: band.minY)
                .allowsHitTesting(false)
        }
    }

    private var bandGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
            .onChanged { drag in
                let base = bandBase ?? (NSEvent.modifierFlags.contains(.command) ? model.selection : [])
                let rect = CGRect(
                    x: min(drag.startLocation.x, drag.location.x),
                    y: min(drag.startLocation.y, drag.location.y),
                    width: abs(drag.location.x - drag.startLocation.x),
                    height: abs(drag.location.y - drag.startLocation.y)
                )

                bandBase = base
                band = rect
                model.selection = base.union(model.visibleItems.filter { tracking.frames[$0.id]?.intersects(rect) == true }.map(\.id))
            }
            .onEnded { _ in
                band = nil
                bandBase = nil
            }
    }

    private func offset(for key: KeyEquivalent) -> Int {
        if layout == .list {
            switch key {
            case .leftArrow: return -rows
            case .rightArrow: return rows
            case .upArrow: return -1
            default: return 1
            }
        }

        switch key {
        case .leftArrow: return -1
        case .rightArrow: return 1
        case .upArrow: return -columns
        default: return columns
        }
    }

    private func move(by offset: Int) {
        let items = model.visibleItems

        guard !items.isEmpty else { return }

        let current = items.lastIndex { model.selection.contains($0.id) }
        let next = current.map { $0 + offset } ?? 0

        guard items.indices.contains(next) else { return }

        model.selection = [items[next].id]
    }

    private func targets(for item: FileItem) -> [FileItem] {
        model.selection.contains(item.id) ? model.selectedItems : [item]
    }

    // the point arrives in the visible area, so it is moved into the scrolled content first
    private func selectForMenu(at point: CGPoint) -> Bool {
        guard viewport.width > 0, CGRect(origin: .zero, size: viewport).contains(point) else { return false }

        let point = CGPoint(x: point.x - tracking.contentOrigin.x, y: point.y - tracking.contentOrigin.y)
        let hit = model.visibleItems.first { tracking.frames[$0.id]?.contains(point) == true }

        if let id = hit?.id {
            if !model.selection.contains(id) {
                model.selection = [id]
                anchor = id
            }
        } else {
            model.selection = []
        }

        return false
    }

    private func select(_ item: FileItem) {
        let flags = NSEvent.modifierFlags
        let items = model.visibleItems

        if flags.contains(.shift), let anchor, let from = items.firstIndex(where: { $0.id == anchor }),
           let to = items.firstIndex(of: item) {
            model.selection = Set(items[min(from, to)...max(from, to)].map(\.id))
            return
        }

        anchor = item.id

        if flags.contains(.command) {
            model.selection.formSymmetricDifference([item.id])
        } else {
            model.selection = [item.id]
        }
    }
}

// written as cells lay out and the grid scrolls, and read only on clicks, so it is kept out of observation
// shortcut: frames of cells scrolled away keep their last position, upgrade if the band ever scrolls the grid
private final class GridTracking {
    var frames: [FileItem.ID: CGRect] = [:]
    var contentOrigin = CGPoint.zero
}
