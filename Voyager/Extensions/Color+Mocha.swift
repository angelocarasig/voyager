//
//  Color+Mocha.swift
//  Voyager
//
//  Created by Angelo Carasig on 10/11/2026.
//

import SwiftUI

// catppuccin mocha, matching the user's ghostty theme
extension Color {
    enum Mocha {
        static let base = Color(hex: 0x1E1E1E)
        static let blue = Color(hex: 0x89B4FA)
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
