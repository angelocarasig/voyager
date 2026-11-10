//
//  WindowBackground.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import AppKit
import SwiftUI

extension View {
    func windowBackground(_ settings: AppSettings) -> some View {
        modifier(WindowBackground(settings: settings))
    }
}

private struct WindowBackground: ViewModifier {
    let settings: AppSettings

    func body(content: Content) -> some View {
        let tinted = content.background(Color.Mocha.base.opacity(settings.backgroundDim), ignoresSafeAreaEdges: .all)

        if WindowBlur.isAvailable {
            tinted
                .background(WindowBlur(radius: Int(settings.backgroundBlur)))
                .containerBackground(.clear, for: .window)
        } else {
            tinted.containerBackground(Material.thin.materialActiveAppearance(.active), for: .window)
        }
    }
}

// public materials only come in five fixed strengths, so the radius goes through the private
// call ghostty and iterm2 use; without it the window keeps the thin material
private struct WindowBlur: NSViewRepresentable {
    let radius: Int

    private typealias Connection = @convention(c) () -> Int32
    private typealias SetRadius = @convention(c) (Int32, UInt32, Int32) -> Int32

    private static let connection = symbol("CGSDefaultConnectionForThread", as: Connection.self)
    private static let setRadius = symbol("CGSSetWindowBackgroundBlurRadius", as: SetRadius.self)

    static var isAvailable: Bool {
        connection != nil && setRadius != nil
    }

    func makeNSView(context: Context) -> BlurView {
        BlurView()
    }

    func updateNSView(_ view: BlurView, context: Context) {
        view.radius = radius
    }

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), name).map { unsafeBitCast($0, to: type) }
    }

    final class BlurView: NSView {
        var radius = 0 {
            didSet { apply() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window, let connection = WindowBlur.connection, let setRadius = WindowBlur.setRadius else { return }

            window.isOpaque = false
            window.backgroundColor = .clear
            _ = setRadius(connection(), UInt32(window.windowNumber), Int32(radius))
        }
    }
}
