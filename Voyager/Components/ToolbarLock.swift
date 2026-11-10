//
//  ToolbarLock.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI

// swiftui has no setting for the toolbar's "Icon and Text" right-click menu, so the
// window's NSToolbar is pinned to icon-only directly
struct ToolbarLock: NSViewRepresentable {
    func makeNSView(context: Context) -> LockView {
        LockView()
    }

    func updateNSView(_ view: LockView, context: Context) {}

    final class LockView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            lock()
        }

        // swiftui can install the toolbar after this view joins the window
        override func layout() {
            super.layout()
            lock()
        }

        private func lock() {
            guard let toolbar = window?.toolbar, toolbar.allowsDisplayModeCustomization || toolbar.displayMode != .iconOnly else { return }

            toolbar.allowsDisplayModeCustomization = false
            toolbar.displayMode = .iconOnly
        }
    }
}
