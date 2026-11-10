//
//  MouseButtons.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI

// right clicks and a mouse's side buttons never reach swiftui gestures, so they are caught
// for this window only; actions are keyed by button number, get the click's point in this view
// (top-left origin), and returning true swallows the click
struct MouseButtons: NSViewRepresentable {
    static let secondary = 1
    static let back = 3
    static let forward = 4

    let actions: [Int: (CGPoint) -> Bool]

    func makeNSView(context: Context) -> MonitorView {
        MonitorView()
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        view.actions = actions
    }

    final class MonitorView: NSView {
        var actions: [Int: (CGPoint) -> Bool] = [:]

        private var monitor: Any?

        override var isFlipped: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }

            guard window != nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown]) { [weak self] event in
                let button = event.buttonNumber
                let windowNumber = event.windowNumber
                let location = event.locationInWindow
                let handled = MainActor.assumeIsolated {
                    self?.handle(button: button, windowNumber: windowNumber, location: location) ?? false
                }

                return handled ? nil : event
            }
        }

        private func handle(button: Int, windowNumber: Int, location: CGPoint) -> Bool {
            guard windowNumber == window?.windowNumber, let action = actions[button] else { return false }

            return action(convert(location, from: nil))
        }
    }
}
