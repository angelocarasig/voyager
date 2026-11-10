//
//  TableBand.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI

// swiftui's table has no selection band, so one is drawn on the nstableview it renders underneath;
// rows are matched by index, so it stands aside whenever the row counts disagree
struct TableBand: NSViewRepresentable {
    // one entry per table row, nil for group headers
    let rows: [URL?]
    let model: BrowserViewModel
    let color: Color

    func makeNSView(context: Context) -> BandView {
        BandView()
    }

    func updateNSView(_ view: BandView, context: Context) {
        view.rows = rows
        view.model = model
        view.color = NSColor(color)
    }

    final class BandView: NSView {
        var rows: [URL?] = []
        var model: BrowserViewModel?
        var color = NSColor.controlAccentColor

        private var monitor: Any?
        private var table: NSTableView?
        private var start = CGPoint.zero
        private var base: Set<URL> = []
        private var anchor: URL?
        private var band: NSView?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }

            guard window != nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
                let handled = MainActor.assumeIsolated { self?.handle(event) ?? false }

                return handled ? nil : event
            }
        }

        private func handle(_ event: NSEvent) -> Bool {
            guard event.window === window else { return false }

            switch event.type {
            case .leftMouseDown:
                return begin(event)
            case .leftMouseDragged:
                guard let table else { return false }

                drag(to: table.convert(event.locationInWindow, from: nil), in: table)

                return true
            case .leftMouseUp:
                guard let table else { return false }

                finish(event, in: table)

                return true
            default:
                return false
            }
        }

        private func begin(_ event: NSEvent) -> Bool {
            guard let model, model.renaming == nil,
                  convert(bounds, to: nil).contains(event.locationInWindow),
                  let table = tableView(at: event.locationInWindow),
                  table.numberOfRows == rows.count else { return false }

            let point = table.convert(event.locationInWindow, from: nil)
            let row = table.row(at: point)
            let column = table.column(at: point)

            if row >= 0 {
                guard rows[row] != nil else { return false }

                if column >= 0, table.tableColumns[column].headerCell.stringValue == "Name" {
                    return false
                }
            }

            self.table = table
            start = point
            base = event.modifierFlags.contains(.command) ? model.selection : []
            table.window?.makeFirstResponder(table)

            return true
        }

        private func drag(to point: CGPoint, in table: NSTableView) {
            guard let model else { return }

            let rect = CGRect(
                x: min(start.x, point.x),
                y: min(start.y, point.y),
                width: abs(point.x - start.x),
                height: abs(point.y - start.y)
            )

            guard rect.width > 2 || rect.height > 2 else { return }

            let band = self.band ?? makeBand(in: table)
            band.frame = rect

            let range = table.rows(in: rect)
            let hit = (range.lowerBound..<range.upperBound).compactMap { rows.indices.contains($0) ? rows[$0] : nil }

            model.selection = base.union(hit)

            if let event = NSApp.currentEvent {
                table.autoscroll(with: event)
            }
        }

        private func finish(_ event: NSEvent, in table: NSTableView) {
            defer {
                band?.removeFromSuperview()
                band = nil
                self.table = nil
            }

            guard band == nil, let model else { return }

            let row = table.row(at: start)

            guard row >= 0, let id = rows[row] else {
                if !event.modifierFlags.contains(.command) {
                    model.selection = []
                }

                return
            }

            click(id, event: event, model: model)
        }

        private func click(_ id: URL, event: NSEvent, model: BrowserViewModel) {
            let flags = event.modifierFlags
            let ids = rows.compactMap(\.self)

            if event.clickCount == 2, let item = model.items.first(where: { $0.id == id }) {
                Task { await model.open(item) }
                return
            }

            if flags.contains(.shift), let anchor = anchor ?? model.selection.first,
               let from = ids.firstIndex(of: anchor), let to = ids.firstIndex(of: id) {
                model.selection = Set(ids[min(from, to)...max(from, to)])
                return
            }

            anchor = id

            if flags.contains(.command) {
                model.selection.formSymmetricDifference([id])
            } else {
                model.selection = [id]
            }
        }

        private func makeBand(in table: NSTableView) -> NSView {
            let band = NSView()
            band.wantsLayer = true
            band.layer?.backgroundColor = color.withAlphaComponent(0.15).cgColor
            band.layer?.borderColor = color.withAlphaComponent(0.6).cgColor
            band.layer?.borderWidth = 1
            table.addSubview(band)
            self.band = band

            return band
        }

        private func tableView(at point: CGPoint) -> NSTableView? {
            var view = window?.contentView?.hitTest(point)

            while let current = view {
                if let table = current as? NSTableView {
                    return table
                }

                view = current.superview
            }

            return nil
        }
    }
}
