//
//  ControlScroll.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI

struct ControlScroll: NSViewRepresentable {
    let action: (Int) -> Void

    func makeNSView(context: Context) -> MonitorView {
        MonitorView()
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        view.action = action
    }

    final class MonitorView: NSView {
        var action: (Int) -> Void = { _ in }

        private var monitor: Any?
        private var accumulated = 0.0

        private let threshold = 8.0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }

            guard window != nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                let windowNumber = event.windowNumber
                let isControl = event.modifierFlags.contains(.control)
                let delta = event.scrollingDeltaY
                let isPrecise = event.hasPreciseScrollingDeltas
                let handled = MainActor.assumeIsolated {
                    self?.handle(windowNumber: windowNumber, isControl: isControl, delta: delta, isPrecise: isPrecise) ?? false
                }

                return handled ? nil : event
            }
        }

        private func handle(windowNumber: Int, isControl: Bool, delta: Double, isPrecise: Bool) -> Bool {
            guard windowNumber == window?.windowNumber, isControl else { return false }

            accumulated += isPrecise ? delta : delta * threshold

            let steps = Int(accumulated / threshold)

            if steps != 0 {
                accumulated -= Double(steps) * threshold
                action(steps)
            }

            return true
        }
    }
}
