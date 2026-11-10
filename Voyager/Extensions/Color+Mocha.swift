//
//  Color+Mocha.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

extension Color {
    enum Mocha {
        static let base = Color(hex: 0x1E1E1E)
    }

    @MainActor
    static var userAccent: Color { Color(hex: SettingsStore.shared.settings.accent) }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
