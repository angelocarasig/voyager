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

    private let cellWidth: CGFloat = 104
    private let spacing: CGFloat = 12
    private let padding: CGFloat = 16
    private let space = "grid"
    private let viewportSpace = "viewport"

    private var columns: Int {
        max(1, Int((viewport.width - padding * 2 + spacing) / (cellWidth + spacing)))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: columns),
                    spacing: spacing
                ) {
                    ForEach(model.items) { item in
                        cell(for: item)
                    }
                }
                .padding(padding)
                .frame(maxWidth: .infinity, minHeight: viewport.height, alignment: .top)
                .background { surface }
                .overlay(alignment: .topLeading) { selectionBand }
                .coordinateSpace(.named(space))
                .onGeometryChange(for: CGPoint.self) { geometry in
                    geometry.frame(in: .named(viewportSpace)).origin
                } action: { origin in
                    tracking.contentOrigin = origin
                }
            }
            .coordinateSpace(.named(viewportSpace))
            .onGeometryChange(for: CGSize.self) { geometry in
                geometry.size
            } action: { size in
                viewport = size
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

    private func cell(for item: FileItem) -> some View {
        FileGridCell(item: item, isSelected: model.selection.contains(item.id), isDropTarget: dropTarget == item.id)
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .named(space))
            } action: { frame in
                tracking.frames[item.id] = frame
            }
            .frame(maxWidth: .infinity)
            .id(item.id)
            .onTapGesture(count: 2) {
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
    }

    // empty space clears the selection on click and draws a selection band on drag
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
                .fill(Color.Mocha.blue.opacity(0.15))
                .strokeBorder(Color.Mocha.blue.opacity(0.6))
                .frame(width: band.width, height: band.height)
                .offset(x: band.minX, y: band.minY)
                .allowsHitTesting(false)
        }
    }

    // command adds to the selection, as in finder
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
                model.selection = base.union(model.items.filter { tracking.frames[$0.id]?.intersects(rect) == true }.map(\.id))
            }
            .onEnded { _ in
                band = nil
                bandBase = nil
            }
    }

    private func offset(for key: KeyEquivalent) -> Int {
        switch key {
        case .leftArrow: -1
        case .rightArrow: 1
        case .upArrow: -columns
        default: columns
        }
    }

    private func move(by offset: Int) {
        guard !model.items.isEmpty else { return }

        let current = model.items.lastIndex { model.selection.contains($0.id) }
        let next = current.map { $0 + offset } ?? 0

        guard model.items.indices.contains(next) else { return }

        model.selection = [model.items[next].id]
    }

    // right-clicking inside the selection acts on all of it, as finder does
    private func targets(for item: FileItem) -> [FileItem] {
        model.selection.contains(item.id) ? model.selectedItems : [item]
    }

    // a right click selects what it lands on, as windows does, then lets the menu open;
    // the point is in the visible area, so it is moved into the scrolled content first
    private func selectForMenu(at point: CGPoint) -> Bool {
        guard viewport.width > 0, CGRect(origin: .zero, size: viewport).contains(point) else { return false }

        let point = CGPoint(x: point.x - tracking.contentOrigin.x, y: point.y - tracking.contentOrigin.y)
        let hit = model.items.first { tracking.frames[$0.id]?.contains(point) == true }

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

        if flags.contains(.shift), let anchor, let from = model.items.firstIndex(where: { $0.id == anchor }),
           let to = model.items.firstIndex(of: item) {
            model.selection = Set(model.items[min(from, to)...max(from, to)].map(\.id))
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

private struct FileGridCell: View {
    let item: FileItem
    let isSelected: Bool
    let isDropTarget: Bool

    var body: some View {
        VStack(spacing: 6) {
            FileIcon(item: item, size: 64)
                .padding(4)
                .background(iconBackground, in: .rect(cornerRadius: 8))

            Text(item.name)
                .font(SettingsStore.shared.settings.font(scale: 12 / 13))
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .foregroundStyle(isSelected ? Color.Mocha.base : Color.primary)
                .background(isSelected ? Color.Mocha.blue : .clear, in: .rect(cornerRadius: 4))
        }
        .contentShape(Rectangle())
    }

    private var iconBackground: Color {
        if isDropTarget {
            return Color.Mocha.blue.opacity(0.3)
        }

        return isSelected ? Color.primary.opacity(0.1) : .clear
    }
}

// written as cells lay out and the grid scrolls, and read only on clicks, so it is kept out of observation
// shortcut: frames of cells scrolled away keep their last position, upgrade if the band ever scrolls the grid
private final class GridTracking {
    var frames: [FileItem.ID: CGRect] = [:]
    var contentOrigin = CGPoint.zero
}

